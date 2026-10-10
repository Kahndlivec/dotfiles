# ═════════════════════════════════════════════════════════════════════════════
#  cp_companion.py — Competitive Companion listener for Sublime Text.
#
#  Click the green plus of the Competitive Companion browser extension on a
#  problem page and this:
#    1. creates a folder for the problem inside your CP repo,
#    2. puts your template in it as the solution file,
#    3. saves every sample test, and
#    4. opens the file in Sublime with the cursor inside solve().
#
#  It listens while Sublime is open. Nothing to start: the extension already
#  sends to port 10043 by default. Toggle it with SPC k c, or from the palette:
#  "CP Companion: Toggle Listener".
#
#  What lands on disk, for Codeforces 2019 A with the default layout:
#
#      <root>/codeforces/2019/A/A.cpp          your template
#      <root>/codeforces/2019/A/A.cpp:tests    the samples, as FOC reads them
#      <root>/codeforces/2019/A/tests/01.in    the same samples as plain files
#      <root>/codeforces/2019/A/tests/01.out
#      <root>/codeforces/2019/A/in.txt         sample 1, for Ctrl+Shift+R
#
#  Nothing that already exists is ever overwritten: clicking the plus twice
#  just reopens the file.
#
#  Where things go is set in CpCompanion.sublime-settings ("root", "path").
#
#  Written to run on Sublime's oldest plugin Python (3.3), hence no f-strings.
#  Outside Sublime the same file runs as a plain script, for testing:
#      python3 cp_companion.py --root /tmp/cp
# ═════════════════════════════════════════════════════════════════════════════
import json
import os
import re
import threading

from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

try:
    import sublime
    import sublime_plugin
except ImportError:
    sublime = None
    sublime_plugin = None

SETTINGS_FILE = "CpCompanion.sublime-settings"
MAX_BODY = 4 * 1024 * 1024   # bytes; a problem with samples is a few KB
MAX_TESTS = 100

DEFAULTS = {
    "enabled": True,
    "port": 10043,
    "root": "~/Documents/cp",
    "path": "{site}/{contest}/{problem}/{problem}.cpp",
    "template": "",
}

FALLBACK_TEMPLATE = (
    "#include <bits/stdc++.h>\n"
    "using namespace std;\n\n"
    "void solve() {\n"
    "    \n"
    "}\n\n"
    "int main() {\n"
    "    ios::sync_with_stdio(false);\n"
    "    cin.tie(nullptr);\n\n"
    "    int T = 1;\n"
    "    // cin >> T;\n"
    "    while (T--) solve();\n"
    "    return 0;\n"
    "}\n"
)


# ─────────────────────────────────────────────────────────────────────────────
#  Naming: turn what the extension sends into folder and file names
# ─────────────────────────────────────────────────────────────────────────────
def slug(text):
    """'G. Castle Defense' -> 'g-castle-defense'. Never empty."""
    s = re.sub(r"[^A-Za-z0-9]+", "-", text or "").strip("-").lower()
    return s or "problem"


def _site(url, group):
    host = (urlparse(url or "").hostname or "").lower()
    parts = [p for p in host.split(".") if p and p != "www"]
    if len(parts) >= 2:
        return slug(parts[-2])           # codeforces.com, open.kattis.com
    if parts:
        return slug(parts[0])
    return slug((group or "misc").split(" - ")[0])


def describe(data):
    """The names a problem can be filed under.

    site      codeforces, atcoder, cses, kattis …
    contest   the judge's own contest id where the URL has one (2019, abc370),
              otherwise the contest title as a slug, otherwise "misc"
    problem   the problem's letter or index where there is one (A, B1),
              otherwise the title as a slug
    name      the full title as a slug (a-max-plus-size)
    """
    url = data.get("url") or ""
    name = data.get("name") or "problem"
    group = data.get("group") or ""
    site = _site(url, group)
    contest = None
    problem = None

    # Codeforces: /contest/2019/problem/A, /gym/104114/problem/B,
    # /problemset/problem/954/G, /group/x/contest/1/problem/A, and the EDU
    # section, which ends the same way.
    m = (re.search(r"/(?:contest|gym)/(\d+)/problem/([A-Za-z0-9]+)", url)
         or re.search(r"/problemset/(?:problem|gymProblem)/(\d+)/([A-Za-z0-9]+)", url))
    if m and site == "codeforces":
        contest, problem = m.group(1), m.group(2).upper()

    # AtCoder: /contests/abc370/tasks/abc370_a
    if contest is None:
        m = re.search(r"/contests/([A-Za-z0-9_-]+)/tasks/[A-Za-z0-9-]+_([A-Za-z0-9]+)", url)
        if m:
            contest, problem = m.group(1).lower(), m.group(2).upper()

    if contest is None:
        category = group.split(" - ", 1)[1] if " - " in group else ""
        contest = slug(category) if category.strip() else "misc"
    if problem is None:
        problem = slug(name)

    return {"site": site, "contest": contest, "problem": problem, "name": slug(name)}


def source_path(data, root, template):
    names = describe(data)
    try:
        rel = template.format(**names)
    except (KeyError, IndexError, ValueError):
        rel = DEFAULTS["path"].format(**names)
    # A path template must never climb out of the repo.
    rel = os.path.normpath(rel)
    if rel.startswith("..") or os.path.isabs(rel):
        rel = DEFAULTS["path"].format(**names)
    return os.path.join(os.path.expanduser(root), rel)


# ─────────────────────────────────────────────────────────────────────────────
#  Files
# ─────────────────────────────────────────────────────────────────────────────
def _read_template(path):
    if path:
        try:
            with open(os.path.expanduser(path), "r", encoding="utf-8") as f:
                text = f.read()
            if text.strip():
                return text
        except (IOError, OSError):
            pass
    return FALLBACK_TEMPLATE


def _write_new(path, text):
    """Write text to path unless something is already there."""
    if os.path.exists(path):
        return False
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return True


def cursor_position(text):
    """(row, col), 1-based, of the first line inside solve()."""
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if re.match(r"\s*void\s+solve\s*\(", line) and i + 1 < len(lines):
            body = lines[i + 1]
            return i + 2, len(body) - len(body.lstrip()) + 1
    return 1, 1


def create_problem(data, cfg):
    """Create the folder, solution file and tests. Returns a summary dict."""
    src = source_path(data, cfg["root"], cfg["path"])
    folder = os.path.dirname(src)
    tests_dir = os.path.join(folder, "tests")
    if not os.path.isdir(tests_dir):
        os.makedirs(tests_dir)

    template = _read_template(cfg.get("template"))
    created = _write_new(src, template)

    tests = [t for t in (data.get("tests") or []) if isinstance(t, dict)][:MAX_TESTS]
    for i, t in enumerate(tests, 1):
        _write_new(os.path.join(tests_dir, "%02d.in" % i), t.get("input") or "")
        _write_new(os.path.join(tests_dir, "%02d.out" % i), t.get("output") or "")
    if tests:
        _write_new(os.path.join(folder, "in.txt"), tests[0].get("input") or "")
        # CppFastOlympicCoding keeps its tests beside the source in
        # "<file>:tests": a JSON list of {"test": input, "correct_answers": [..]}.
        foc = [{"test": t.get("input") or "",
                "correct_answers": [(t.get("output") or "").strip()]} for t in tests]
        _write_new(src + ":tests", json.dumps(foc, indent=4))

    try:
        with open(src, "r", encoding="utf-8") as f:
            row, col = cursor_position(f.read())
    except (IOError, OSError):
        row, col = 1, 1
    batch = data.get("batch") or {}
    return {
        "src": src, "created": created, "tests": len(tests),
        "row": row, "col": col,
        "name": data.get("name") or os.path.basename(src),
        "batch_id": batch.get("id"), "batch_size": batch.get("size") or 1,
    }


# ─────────────────────────────────────────────────────────────────────────────
#  The listener
# ─────────────────────────────────────────────────────────────────────────────
class _Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length") or 0)
            if length <= 0 or length > MAX_BODY:
                raise ValueError("bad length")
            body = self.rfile.read(length).decode("utf-8", "replace")
            data = json.loads(body)
        except (ValueError, TypeError):
            self.send_response(400)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()
        if isinstance(data, dict):
            self.server.on_problem(data)

    def do_GET(self):
        # Lets you check it from a terminal: curl localhost:10043
        msg = b"cp_companion is listening\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(msg)))
        self.end_headers()
        self.wfile.write(msg)

    def log_message(self, *args):
        pass


class _Server(HTTPServer):
    allow_reuse_address = True


class Listener(object):
    def __init__(self):
        self.server = None
        self.thread = None

    def running(self):
        return self.server is not None

    def start(self, port, on_problem):
        if self.server is not None:
            return
        server = _Server(("127.0.0.1", int(port)), _Handler)   # may raise OSError
        server.on_problem = on_problem
        thread = threading.Thread(target=server.serve_forever, name="cp_companion")
        thread.daemon = True
        thread.start()
        self.server, self.thread = server, thread

    def stop(self):
        server, self.server, self.thread = self.server, None, None
        if server is not None:
            server.shutdown()
            server.server_close()


_listener = Listener()
_batches = {}   # batch id -> first file opened, so a whole contest ends on A


# ─────────────────────────────────────────────────────────────────────────────
#  Inside Sublime Text
# ─────────────────────────────────────────────────────────────────────────────
def _config():
    cfg = dict(DEFAULTS)
    if sublime is not None:
        s = sublime.load_settings(SETTINGS_FILE)
        for key in DEFAULTS:
            value = s.get(key)
            if value is not None and value != "":
                cfg[key] = value
    return cfg


def _open_in_sublime(info):
    window = sublime.active_window()
    if window is None:
        return
    window.open_file("%s:%d:%d" % (info["src"], info["row"], info["col"]),
                     sublime.ENCODED_POSITION)
    bid = info.get("batch_id")
    if bid and info.get("batch_size", 1) > 1:
        first = _batches.setdefault(bid, info)
        if first is not info:
            # Parsing a whole contest opens every problem; finish on the first.
            window.open_file("%s:%d:%d" % (first["src"], first["row"], first["col"]),
                             sublime.ENCODED_POSITION)
        while len(_batches) > 20:
            _batches.pop(next(iter(_batches)))
    sublime.status_message("cp: %s - %d sample%s%s" % (
        info["name"], info["tests"], "" if info["tests"] == 1 else "s",
        "" if info["created"] else " (already existed, reopened)"))


def _on_problem_sublime(data):
    def work():
        try:
            info = create_problem(data, _config())
        except Exception as e:   # never let one bad payload kill the listener
            sublime.status_message("cp_companion: %s" % e)
            print("cp_companion: could not create the problem: %s" % e)
            return
        _open_in_sublime(info)
    # Sublime's API must be called from its own thread, not the server's.
    sublime.set_timeout(work, 0)


def _start_in_sublime(announce=False):
    cfg = _config()
    try:
        _listener.start(cfg["port"], _on_problem_sublime)
    except (OSError, IOError) as e:
        msg = "cp_companion: port %s is busy (%s)" % (cfg["port"], e)
        print(msg)
        sublime.status_message(msg)
        return False
    if announce:
        sublime.status_message("cp_companion: listening on %s, saving to %s" % (
            cfg["port"], os.path.expanduser(cfg["root"])))
    return True


def plugin_loaded():
    if _config().get("enabled"):
        _start_in_sublime()


def plugin_unloaded():
    _listener.stop()


if sublime_plugin is not None:
    class CpCompanionToggleCommand(sublime_plugin.WindowCommand):
        """SPC k c — start or stop the listener for this session."""
        def run(self):
            if _listener.running():
                _listener.stop()
                sublime.status_message("cp_companion: stopped")
            else:
                _start_in_sublime(announce=True)


# ─────────────────────────────────────────────────────────────────────────────
#  Outside Sublime: a plain script, mostly for testing
# ─────────────────────────────────────────────────────────────────────────────
def _main():
    import argparse
    import subprocess
    import time
    ap = argparse.ArgumentParser(description="Competitive Companion listener")
    ap.add_argument("--root", default=DEFAULTS["root"])
    ap.add_argument("--path", default=DEFAULTS["path"])
    ap.add_argument("--template", default="")
    ap.add_argument("--port", type=int, default=DEFAULTS["port"])
    ap.add_argument("--no-open", action="store_true", help="do not call subl")
    args = ap.parse_args()
    cfg = {"root": args.root, "path": args.path, "template": args.template}

    def on_problem(data):
        info = create_problem(data, cfg)
        print("%s  %s  (%d samples)" % ("new " if info["created"] else "seen",
                                       info["src"], info["tests"]))
        if not args.no_open:
            try:
                subprocess.Popen(["subl", "%s:%d:%d" % (info["src"], info["row"], info["col"])])
            except OSError:
                pass

    _listener.start(args.port, on_problem)
    print("listening on http://127.0.0.1:%d, saving to %s" % (args.port, os.path.expanduser(args.root)))
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        _listener.stop()


if __name__ == "__main__":
    _main()

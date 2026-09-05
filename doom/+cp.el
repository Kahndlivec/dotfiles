;;; +cp.el -*- lexical-binding: t; -*-
;;
;; Competitive programming layer.
;;
;; Replaces what Sublime + CppFastOlympicCoding did for you, but the loop runs
;; in-process, so there is no window switch between edit / build / test.
;;
;; Everything is under the localleader in C++ buffers, i.e. `SPC m` (or `,`):
;;
;;   SPC m b   build (g++-16, -O2)
;;   SPC m B   build with sanitizers (clang++, ASan+UBSan)
;;   SPC m t   build + run every tests/*.in and diff against tests/*.out
;;   SPC m r   build + run interactively (type your own stdin)
;;   SPC m s   stress test against brute.cpp using gen.cpp
;;   SPC m n   new problem directory from your template
;;   SPC m c   toggle the Competitive Companion listener
;;   SPC m p   paste the current problem into the CP log (org capture)

(require 'cl-lib)
(require 'json)

;;; ---------------------------------------------------------------------
;;; Settings
;;; ---------------------------------------------------------------------

(defvar +cp-root (expand-file-name "~/Documents/cp/")
  "Where problem directories are created.")

(defvar +cp-template-file (expand-file-name "templates/cp.cpp" doom-user-dir)
  "Your C++ template. Drop your own file here; it is copied verbatim.")

(defvar +cp-compiler "g++-16"
  "Compiler for normal builds. Matches your Homebrew default.")

(defvar +cp-debug-compiler "clang++"
  "Compiler for sanitizer builds. clang++ has the better ASan on macOS.")

(defvar +cp-standard "-std=c++23")

(defvar +cp-fast-flags
  '("-O2" "-Wall" "-Wextra" "-Wshadow" "-DLOCAL")
  "Flags for the normal build — what you actually submit against.
No -Wconversion: it fires on every ordinary int/size_t mix in CP code, and
warnings you learn to ignore are worse than no warnings.")

(defvar +cp-debug-flags
  '("-g" "-O1" "-fno-omit-frame-pointer"
    "-fsanitize=address,undefined"
    "-fno-sanitize-recover=all"
    "-DLOCAL")
  "Flags for the sanitizer build. Catches UB and out-of-bounds.")

(defvar +cp-time-limit 5
  "Seconds before a test run is killed. Needs coreutils `timeout`/`gtimeout`.")

(defvar +cp-companion-port 10043
  "Port the Competitive Companion browser extension posts to.")

(defvar +cp-build-dir (expand-file-name "cp-build/" temporary-file-directory)
  "Binaries live outside the source tree so git stays clean.")


;;; ---------------------------------------------------------------------
;;; Internals
;;; ---------------------------------------------------------------------

(defun +cp--timeout-program ()
  "Return a coreutils timeout binary, or nil."
  (or (executable-find "timeout") (executable-find "gtimeout")))

(defun +cp--source ()
  "Current C++ source file, or signal."
  (or (and buffer-file-name
           (string-match-p "\\.\\(cpp\\|cc\\|cxx\\)\\'" buffer-file-name)
           buffer-file-name)
      (user-error "Not visiting a C++ source file")))

(defun +cp--binary (src &optional suffix)
  (make-directory +cp-build-dir t)
  (expand-file-name
   (concat (file-name-base src) (or suffix "")
           "-" (substring (md5 (expand-file-name src)) 0 8))
   +cp-build-dir))

(defun +cp--compile (src bin compiler flags)
  "Compile SRC to BIN. Return nil on success, else the compiler output."
  (let ((buf (get-buffer-create "*cp compile*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t)) (erase-buffer))
      (setq default-directory (file-name-directory src)))
    (let ((status (apply #'call-process compiler nil buf nil
                         (append (list +cp-standard) flags
                                 (list "-o" bin src)))))
      (if (eq status 0)
          nil
        (with-current-buffer buf (buffer-string))))))

(defun +cp--show-compile-error (output)
  (let ((buf (get-buffer-create "*cp compile*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert output))
      (compilation-mode)
      (goto-char (point-min)))
    (pop-to-buffer buf)))

(defun +cp--build (&optional debug)
  "Build the current buffer's file. Return the binary path, or nil."
  (save-buffer)
  (let* ((src (+cp--source))
         (bin (+cp--binary src (if debug "-dbg" nil)))
         (err (+cp--compile src bin
                            (if debug +cp-debug-compiler +cp-compiler)
                            (if debug +cp-debug-flags +cp-fast-flags))))
    (if err (progn (+cp--show-compile-error err) nil)
      (when-let ((w (get-buffer-window "*cp compile*")))
        (delete-window w))
      bin)))

(defun +cp--run-once (bin infile)
  "Run BIN with INFILE on stdin. Return (EXIT STDOUT SECONDS STDERR).
stdout and stderr are captured SEPARATELY and this matters: your dbg() macro
writes to stderr, and a judge only ever compares stdout. Merging them makes a
correct solution look like a wrong answer."
  (let ((errfile (make-temp-file "cp-stderr")))
    (unwind-protect
        (with-temp-buffer
          (let* ((to (+cp--timeout-program))
                 (start (float-time))
                 (exit (if to
                           (call-process to infile (list t errfile) nil
                                         (number-to-string +cp-time-limit) bin)
                         (call-process bin infile (list t errfile) nil)))
                 (secs (- (float-time) start))
                 (err (with-temp-buffer
                        (insert-file-contents errfile)
                        (buffer-string))))
            (list exit (buffer-string) secs err)))
      (ignore-errors (delete-file errfile)))))

(defun +cp--normalize (s)
  "Trim trailing whitespace per line and at the end, like a checker would."
  (string-trim-right
   (mapconcat #'string-trim-right (split-string (or s "") "\n") "\n")))

(defun +cp--tests-dir (src)
  (expand-file-name "tests" (file-name-directory src)))

(defun +cp--indent (s)
  (concat (mapconcat (lambda (l) (concat "    " l))
                     (split-string (or s "") "\n") "\n")
          "\n"))

(defun +cp--slug (name)
  (let ((s (downcase (replace-regexp-in-string "[^A-Za-z0-9]+" "-" (or name "problem")))))
    (string-trim s "-+" "-+")))


;;; ---------------------------------------------------------------------
;;; Commands
;;; ---------------------------------------------------------------------

;;;###autoload
(defun +cp/build ()
  "Compile the current file with the fast flags."
  (interactive)
  (when (+cp--build nil) (message "cp: build ok")))

;;;###autoload
(defun +cp/build-debug ()
  "Compile the current file with ASan + UBSan."
  (interactive)
  (when (+cp--build t) (message "cp: sanitizer build ok")))

;;;###autoload
(defun +cp/test ()
  "Build, then run every tests/*.in and diff against tests/*.out."
  (interactive)
  (let* ((src (+cp--source))
         (bin (+cp--build nil)))
    (when bin
      (let* ((dir (+cp--tests-dir src))
             (ins (and (file-directory-p dir)
                       (sort (directory-files dir t "\\.in\\'") #'string<)))
             (buf (get-buffer-create "*cp tests*"))
             (pass 0) (fail 0))
        (unless ins (user-error "No tests in %s" dir))
        (with-current-buffer buf
          (let ((inhibit-read-only t))
            (erase-buffer)
            (dolist (in ins)
              (cl-destructuring-bind (exit out secs err) (+cp--run-once bin in)
                (let* ((expfile (concat (file-name-sans-extension in) ".out"))
                       (expected (and (file-exists-p expfile)
                                      (with-temp-buffer
                                        (insert-file-contents expfile)
                                        (buffer-string))))
                       (got (+cp--normalize out))
                       (want (and expected (+cp--normalize expected)))
                       (verdict
                        (cond ((not (eq exit 0))
                               (if (eq exit 124) "TLE" (format "RTE(%s)" exit)))
                              ((null want) "RAN")
                              ((string= got want) "OK")
                              (t "WA"))))
                  (if (member verdict '("OK" "RAN")) (cl-incf pass) (cl-incf fail))
                  (insert (format "── %-14s %-8s %.3fs\n"
                                  (file-name-nondirectory in) verdict secs))
                  (unless (string= verdict "OK")
                    (insert "  input:\n")
                    (insert (+cp--indent (with-temp-buffer
                                           (insert-file-contents in)
                                           (buffer-string))))
                    (insert "  got:\n" (+cp--indent got) "\n")
                    (when want (insert "  want:\n" (+cp--indent want) "\n")))
                  ;; stderr shown whether or not the test passed — that's where
                  ;; your dbg() output lives, and it's most useful on a pass
                  ;; that you don't trust.
                  (unless (string-empty-p (string-trim (or err "")))
                    (insert "  stderr:\n" (+cp--indent (string-trim-right err))))
                  (insert "\n"))))
            (goto-char (point-min))
            (insert (format "%d passed, %d failed\n\n" pass fail)))
          (special-mode)
          (setq-local truncate-lines nil))
        (display-buffer buf)
        (message "cp: %d passed, %d failed" pass fail)))))

;;;###autoload
(defun +cp/run ()
  "Build, then run interactively so you can type stdin yourself."
  (interactive)
  (let ((bin (+cp--build nil)))
    (when bin
      (let ((buf (make-comint "cp-run" bin)))
        (pop-to-buffer buf)
        (goto-char (point-max))))))

;;;###autoload
(defun +cp/stress (iterations)
  "Stress-test sol against brute.cpp using gen.cpp in the same directory.
gen.cpp must accept a seed as argv[1]. On a mismatch the failing input is
written to tests/hack.in and opened."
  (interactive "p")
  (let* ((n (if (> iterations 1) iterations 300))
         (src (+cp--source))
         (dir (file-name-directory src))
         (brute (expand-file-name "brute.cpp" dir))
         (gen   (expand-file-name "gen.cpp" dir)))
    (unless (file-exists-p brute) (user-error "No brute.cpp in %s" dir))
    (unless (file-exists-p gen)   (user-error "No gen.cpp in %s" dir))
    (let ((main-bin  (+cp--build nil))
          (brute-bin (+cp--binary brute))
          (gen-bin   (+cp--binary gen)))
      (unless main-bin (user-error "Main build failed"))
      (dolist (pair (list (cons brute brute-bin) (cons gen gen-bin)))
        (let ((err (+cp--compile (car pair) (cdr pair)
                                 +cp-compiler +cp-fast-flags)))
          (when err (+cp--show-compile-error err)
                (user-error "Failed to build %s" (file-name-nondirectory (car pair))))))
      (let ((tmp (make-temp-file "cp-stress" nil ".in"))
            (found nil))
        (cl-loop for i from 1 to n
                 until found
                 do (with-temp-file tmp
                      (call-process gen-bin nil t nil (number-to-string i)))
                    (let ((a (+cp--normalize (nth 1 (+cp--run-once main-bin tmp))))
                          (b (+cp--normalize (nth 1 (+cp--run-once brute-bin tmp)))))
                      (when (not (string= a b))
                        (setq found i)
                        (let ((hack (expand-file-name "tests/hack.in" dir)))
                          (make-directory (file-name-directory hack) t)
                          (copy-file tmp hack t)
                          (message "cp: mismatch on seed %d -> tests/hack.in" i)
                          (find-file-other-window hack))))
                 finally (unless found
                           (message "cp: %d random tests, no mismatch" n)))))))

;;;###autoload
(defun +cp/new-problem (name)
  "Create a problem directory under `+cp-root' from your template."
  (interactive "sProblem: ")
  (let* ((slug (+cp--slug name))
         (dir (expand-file-name slug +cp-root))
         (src (expand-file-name (concat slug ".cpp") dir)))
    (make-directory (expand-file-name "tests" dir) t)
    (unless (file-exists-p src)
      (if (file-exists-p +cp-template-file)
          (copy-file +cp-template-file src)
        (with-temp-file src
          (insert "#include <bits/stdc++.h>\nusing namespace std;\n\n"
                  "int main() {\n"
                  "    ios::sync_with_stdio(false);\n"
                  "    cin.tie(nullptr);\n\n"
                  "    return 0;\n}\n"))))
    (find-file src)))

;;;###autoload
(defun +cp/log-problem ()
  "Capture this problem into your CP log in org."
  (interactive)
  (org-capture nil "p"))


;;; ---------------------------------------------------------------------
;;; Competitive Companion listener
;;; ---------------------------------------------------------------------
;; Point the browser extension at http://localhost:10043 . Clicking the green
;; plus on a Codeforces problem creates the directory, writes every sample as
;; tests/01.in / 01.out, seeds your template, and opens the file.

(defvar +cp--companion-process nil)

(defun +cp--companion-handle (data)
  (let* ((name (gethash "name" data))
         (group (gethash "group" data))
         (url (gethash "url" data))
         (tests (gethash "tests" data))
         (slug (+cp--slug name))
         (contest (+cp--slug (or group "misc")))
         (dir (expand-file-name (concat contest "/" slug) +cp-root))
         (src (expand-file-name (concat slug ".cpp") dir)))
    (make-directory (expand-file-name "tests" dir) t)
    (unless (file-exists-p src)
      (if (file-exists-p +cp-template-file)
          (copy-file +cp-template-file src)
        (with-temp-file src (insert "#include <bits/stdc++.h>\n"))))
    (cl-loop for tc across tests
             for i from 1
             do (write-region (or (gethash "input" tc) "") nil
                              (format "%s/tests/%02d.in" dir i) nil 'silent)
                (write-region (or (gethash "output" tc) "") nil
                              (format "%s/tests/%02d.out" dir i) nil 'silent))
    (find-file src)
    (message "cp: %s (%s) — %d samples — %s"
             name contest (length tests) (or url ""))))

(defun +cp--companion-filter (proc chunk)
  (let ((acc (concat (or (process-get proc :acc) "") chunk)))
    (process-put proc :acc acc)
    (when (string-match "\r\n\r\n\\|\n\n" acc)
      (let ((body (substring acc (match-end 0))))
        (condition-case nil
            (let ((data (json-parse-string body)))
              (ignore-errors
                (process-send-string
                 proc "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"))
              (delete-process proc)
              (+cp--companion-handle data))
          ;; body not complete yet — wait for more
          (json-parse-error nil)
          (error nil))))))

;;;###autoload
(defun +cp/companion-toggle ()
  "Start or stop the Competitive Companion listener."
  (interactive)
  (if (process-live-p +cp--companion-process)
      (progn (delete-process +cp--companion-process)
             (setq +cp--companion-process nil)
             (message "cp: companion listener stopped"))
    (setq +cp--companion-process
          (make-network-process
           :name "cp-companion"
           :service +cp-companion-port
           :host 'local
           :server t
           :family 'ipv4
           :coding 'utf-8
           :filter #'+cp--companion-filter))
    (message "cp: companion listening on %d" +cp-companion-port)))


;;; ---------------------------------------------------------------------
;;; Keys
;;; ---------------------------------------------------------------------

;; Global prefix. `SPC m' is the localleader and only exists inside a C++
;; buffer — no good for `new problem', which is what you run when you don't
;; have one yet. `SPC k' works everywhere, including the dashboard.
(map! :leader
      (:prefix-map ("k" . "competitive")
       :desc "New problem"         "n" #'+cp/new-problem
       :desc "Companion listener"  "c" #'+cp/companion-toggle
       :desc "Build"               "b" #'+cp/build
       :desc "Build (sanitizers)"  "B" #'+cp/build-debug
       :desc "Test samples"        "t" #'+cp/test
       :desc "Run interactively"   "r" #'+cp/run
       :desc "Stress test"         "s" #'+cp/stress
       :desc "Log problem"         "p" #'+cp/log-problem))

;; Bound separately for c++-mode and c++-ts-mode: which one you land in depends
;; on whether Doom's cc module hands you tree-sitter, and referring to a keymap
;; that doesn't exist yet is a config-load error.
(map! :after cc-mode
      :map c++-mode-map
      :localleader
      :desc "Build"               "b" #'+cp/build
      :desc "Build (sanitizers)"  "B" #'+cp/build-debug
      :desc "Test samples"        "t" #'+cp/test
      :desc "Run interactively"   "r" #'+cp/run
      :desc "Stress test"         "s" #'+cp/stress
      :desc "New problem"         "n" #'+cp/new-problem
      :desc "Companion listener"  "c" #'+cp/companion-toggle
      :desc "Log problem"         "p" #'+cp/log-problem)

(map! :after c-ts-mode
      :map c++-ts-mode-map
      :localleader
      :desc "Build"               "b" #'+cp/build
      :desc "Build (sanitizers)"  "B" #'+cp/build-debug
      :desc "Test samples"        "t" #'+cp/test
      :desc "Run interactively"   "r" #'+cp/run
      :desc "Stress test"         "s" #'+cp/stress
      :desc "New problem"         "n" #'+cp/new-problem
      :desc "Companion listener"  "c" #'+cp/companion-toggle
      :desc "Log problem"         "p" #'+cp/log-problem)

;; C++ defaults that suit CP rather than production code.
(add-hook! (c++-mode c++-ts-mode)
  (defun +cp-buffer-setup-h ()
    (setq-local c-basic-offset 4
                indent-tabs-mode nil
                compile-command (format "%s %s %s %s"
                                        +cp-compiler +cp-standard
                                        (string-join +cp-fast-flags " ")
                                        (or (buffer-file-name) "")))))

(provide '+cp)
;;; +cp.el ends here

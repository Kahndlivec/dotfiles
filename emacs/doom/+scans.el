;;; +scans.el --- iPad handwriting -> org notes  -*- lexical-binding: t; -*-
;;
;; The loop this supports:
;;
;;   iPad (GoodNotes page or lasso)  →  export to Drive/Org-inbox  →  `SPC n i'
;;   drops the newest export into the org file you're writing, copied into
;;   assets/ next to your notes  →  `SPC n p' commits and pushes the notes to
;;   GitHub. The iPad clones that same repo with Working Copy and reads it in
;;   Orgro, images and all. Nothing syncs on a schedule; you decide when.
;;
;; Drive/notes stays untouched — that's GoodNotes' own backup of whole
;; notebooks. Point `+scans-inbox' at it if you ever want to import from there.
;;
;; Why copy instead of linking into ~/GoogleDrive: the Drive folder is a network
;; mount. A link into it breaks whenever the mount isn't up, and Orgro on the
;; iPad can't follow it. Files under assets/ travel with the notes.
;;
;;   SPC n i   insert the newest export (the usual one)
;;   SPC n I   pick from the last exports
;;   SPC n v   paste an image from the clipboard (org-download)
;;   SPC n p   push notes to Drive now

(defvar +scans-inbox (expand-file-name "~/GoogleDrive/Org-inbox/")
  "Folder the iPad exports into. Override in +local.el if you rename it.")

(defvar +scans-extensions '("png" "jpg" "jpeg" "heic" "pdf")
  "Files to consider exports.")

(defvar +scans-archive t
  "Move an export into Notes-inbox/imported/ after it lands in a note.")

(defvar +scans-width 600
  "Inline display width, in pixels, of an inserted scan.")

(defvar +scans-pdf-dpi 200
  "Resolution used when a PDF export is turned into images.")

(defun +scans--assets-dir ()
  "Where images live: assets/ next to the notes."
  (or (bound-and-true-p +notes-attachments-dir)
      (expand-file-name "assets/" (or (bound-and-true-p org-directory) "~/Documents/notes/"))))

(defun +scans--files ()
  "Exports in `+scans-inbox', newest first."
  (when (file-directory-p +scans-inbox)
    (sort (seq-filter
           (lambda (f)
             (and (file-regular-p f)
                  (member (downcase (or (file-name-extension f) "")) +scans-extensions)))
           (directory-files +scans-inbox t "\\`[^.]" t))
          (lambda (a b) (time-less-p (file-attribute-modification-time (file-attributes b))
                                     (file-attribute-modification-time (file-attributes a)))))))

(defun +scans--slug (file)
  (let ((base (downcase (file-name-base file))))
    (replace-regexp-in-string "\\(^-\\|-$\\)" ""
                              (replace-regexp-in-string "[^a-z0-9]+" "-" base))))

(defun +scans--import (src)
  "Copy SRC into the assets folder. Return the list of files to link.
A PDF becomes one PNG per page when pdftoppm is available."
  (let* ((assets (+scans--assets-dir))
         (stamp (format-time-string "%Y%m%d-%H%M%S"))
         (slug (+scans--slug src))
         (ext (downcase (or (file-name-extension src) "")))
         out)
    (make-directory assets t)
    (if (and (string= ext "pdf") (executable-find "pdftoppm"))
        (let ((prefix (expand-file-name (format "%s-%s" stamp slug) assets)))
          (call-process "pdftoppm" nil nil nil "-png" "-r"
                        (number-to-string +scans-pdf-dpi) (expand-file-name src) prefix)
          (setq out (directory-files assets t
                                     (concat "\\`" (regexp-quote (file-name-nondirectory prefix))
                                             "-?[0-9]*\\.png\\'"))))
      (let ((dest (expand-file-name (format "%s-%s.%s" stamp slug ext) assets)))
        (copy-file src dest t)
        (setq out (list dest))))
    (when (and +scans-archive out)
      (let ((done (expand-file-name "imported/" +scans-inbox)))
        (make-directory done t)
        (ignore-errors (rename-file src (expand-file-name (file-name-nondirectory src) done) t))))
    (sort out #'string<)))

(defun +scans--insert-links (files)
  "Insert org links to FILES at point, relative to the current file."
  (unless (derived-mode-p 'org-mode)
    (user-error "Not an org buffer"))
  (dolist (f files)
    (let ((link (if buffer-file-name
                    (file-relative-name f (file-name-directory buffer-file-name))
                  f)))
      (unless (bolp) (insert "\n"))
      (insert (format "#+ATTR_ORG: :width %d\n[[file:%s]]\n" +scans-width link))))
  (when (fboundp 'org-redisplay-inline-images) (org-redisplay-inline-images))
  (message "Inserted %d image%s" (length files) (if (= 1 (length files)) "" "s")))

;;;###autoload
(defun +scans-insert (file)
  "Pick an export from the inbox and insert it into this note."
  (interactive
   (let ((files (+scans--files)))
     (unless files
       (user-error "Nothing in %s — is the iPad export synced and ~/GoogleDrive mounted?"
                   (abbreviate-file-name +scans-inbox)))
     (list (completing-read "Export: " (mapcar #'file-name-nondirectory files) nil t))))
  (let* ((files (+scans--files))
         (src (seq-find (lambda (f) (string= (file-name-nondirectory f) file)) files)))
    (+scans--insert-links (+scans--import src))))

;;;###autoload
(defun +scans-insert-latest ()
  "Insert the newest export from the inbox into this note."
  (interactive)
  (let ((src (car (+scans--files))))
    (unless src
      (user-error "Nothing in %s — is the iPad export synced and ~/GoogleDrive mounted?"
                  (abbreviate-file-name +scans-inbox)))
    (+scans--insert-links (+scans--import src))))

;;;###autoload
(defun +scans-save-notes ()
  "Save the notes: commit and push them to GitHub.
That is the sync — the iPad pulls the same repo in Working Copy."
  (interactive)
  (let ((script (expand-file-name "~/dotfiles/bin/notes-sync")))
    (unless (file-executable-p script) (user-error "Not found: %s" script))
    (when (buffer-file-name) (save-buffer))
    (save-some-buffers t (lambda () (and buffer-file-name
                                         (string-prefix-p (expand-file-name (or (bound-and-true-p org-directory) "~/Documents/notes/"))
                                                          buffer-file-name))))
    (let ((buf (get-buffer-create "*notes-sync*")))
      (with-current-buffer buf (erase-buffer))
      (make-process
       :name "notes-sync" :buffer buf :command (list script)
       :sentinel (lambda (_p event)
                   (if (string-match-p "finished" event)
                       (message "Notes saved: %s"
                                (string-join (split-string (string-trim (with-current-buffer buf (buffer-string))) "\n") " | "))
                     (message "notes-sync had trouble — see *notes-sync*")))))))

(provide '+scans)
;;; +scans.el ends here

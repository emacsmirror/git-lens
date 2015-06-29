;;; git-lens.el --- Show new, deleted or modified files in branch  -*- lexical-binding: t; -*-

;; Copyright (C) 2015  Peter Stiernström

;; Author: Peter Stiernström <peter@stiernstrom.se>
;; Keywords: vc, convenience
;; Version: 0.2
;; Package-Requires: ((emacs "24.4"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; git-lens will give you a sidebar listing added, modified or deleted
;; files in your current git branch when compared to master.

;;; Code:

(require 'subr-x)

(defface git-lens-header
 '((default :weight bold :height 1.1 :foreground "orange"))
 "Face for branch files header."
 :group 'git-lens)

(defun git-lens--root-directory ()
 "Repository root directory."
 (with-temp-buffer
  (when (zerop (process-file vc-git-program nil t nil "rev-parse" "--show-toplevel"))
   (string-trim (buffer-substring-no-properties (point-min) (point-max))))))

(defun git-lens--current-branch ()
 "Name of the current branch."
 (with-temp-buffer
  (when (zerop (process-file vc-git-program nil t nil "rev-parse" "--abbrev-ref" "HEAD"))
   (string-trim (buffer-substring-no-properties (point-min) (point-max))))))

(defun git-lens--files (status)
 "Files with STATUS for diff between master and the current branch."
 (let (files)
  (with-temp-buffer
   (when (zerop (process-file vc-git-program nil t nil "diff" "--name-status"
                 (concat "master.." (git-lens--current-branch))))
    (goto-char (point-min))
    (while (not (eobp))
     (let ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
      (when (string-prefix-p status line)
       (push (string-trim (string-remove-prefix status line)) files)))
     (forward-line))))
  files))

(defun git-lens--buffer-name ()
 "Buffer name for git lens buffer."
 (format "*Git Lens: master..%s*" (git-lens--current-branch)))

(defun git-lens--file-at-point ()
 "Full path to file at point in lens buffer."
 (concat (git-lens--root-directory) "/"
  (buffer-substring-no-properties
   (line-beginning-position)
   (line-end-position))))

(defun git-lens--insert (status header)
 "Insert files matching STATUS and prepend buffer with HEADER."
 (setq buffer-read-only nil)
 (erase-buffer)
 (insert (propertize header 'face 'git-lens-header))
 (newline)
 (dolist (file (git-lens--files status))
  (insert file)
  (newline))
 (goto-char (point-min))
 (forward-line)
 (setq buffer-read-only t)
 (git-lens-fit-window-horizontally))

(defun git-lens-added ()
 "Show added files in branch."
 (interactive)
 (git-lens--insert "A" "Added files"))

(defun git-lens-deleted ()
 "Show delete files in branch."
 (interactive)
 (git-lens--insert "D" "Deleted files"))

(defun git-lens-modified ()
 "Show modified files in branch."
 (interactive)
 (git-lens--insert "M" "Modified files"))

(defun git-lens-fit-window-horizontally ()
 "Fit window to buffer contents horizontally."
 (interactive)
 (let* ((lines (split-string (buffer-string) "\n" t))
        (line-lengths (mapcar 'length lines))
        (desired-width (+ 1 (apply 'max line-lengths)))
        (max-width (/ (frame-width) 2))
        (new-width (max (min desired-width max-width) window-min-width)))
  (if (> (window-width) new-width)
   (shrink-window-horizontally
    (- (window-width) (max window-min-width (- (window-width) (- (window-width) new-width)))))
   (enlarge-window-horizontally (- new-width (window-width))))))

(defun git-lens-find-file ()
 "Find file at point."
 (interactive)
 (let ((file (git-lens--file-at-point)))
  (if (file-exists-p file)
   (progn
    (condition-case err
     (windmove-right)
     (error
      (split-window-horizontally)
      (windmove-right)))
    (find-file file))
   (message "Can't visit deleted file"))))

(defun git-lens-quit ()
 "Quit the git lens buffer."
 (interactive)
 (kill-buffer)
 (delete-window))

(defvar git-lens-mode-map
 (let ((keymap (make-sparse-keymap)))
  (define-key keymap (kbd "<return>") 'git-lens-find-file)
  (define-key keymap (kbd "A") 'git-lens-added)
  (define-key keymap (kbd "D") 'git-lens-deleted)
  (define-key keymap (kbd "M") 'git-lens-modified)
  (define-key keymap (kbd "q") 'git-lens-quit)
  keymap))

(define-derived-mode git-lens-mode fundamental-mode "Git Lens Mode"
 (setq mode-name "GitLens")
 (setq buffer-read-only t)
 (setq truncate-lines t))

 ;;;###autoload
(defun git-lens ()
 "Start git lens."
 (interactive)
 (split-window-horizontally)
 (switch-to-buffer (get-buffer-create (git-lens--buffer-name)))
 (git-lens-added)
 (git-lens-mode))

(provide 'git-lens)
;;; git-lens.el ends here

(require 'org-page-util)

(defun op/publish-changes (status-list, pub-root-dir)
  "This function is for two purposes:
1. publish changed org files to html
2. delete html files which are relevant to deleted org files.
STATUS-LIST is a list, each element is a con cell, car is full path to org file,
while cdr is a symbol 'update or 'delete, standing for the org file is updated
or deleted."
  (if status-list
      (mapc (lambda (cell)
              (if (eq (cdr cell) 'update)
                  (op/handle-modified-file (car cell) pub-root-dir) ; update
                (op/handle-deleted-file (car cell))))  ; deletion
            status-list)))

(defun op/read-org-option (option)
  "Read option value of org file opened in current buffer.
e.g:
#+TITLE: this is title
will return \"this is title\" if OPTION is \"TITLE\""
  (let ((match-regexp (org-make-options-regexp `(,option))))
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward match-regexp nil t)
          (match-string-no-properties 2 nil)))))

(defun op/generate-uri (creation-date title)
  "Generate URI of org file opened in current buffer. It will be firstly read
from #+URI property, if it is not presented, will be created by CREATION-DATE
and TITLE, like: /blog/2013/03/07/this-is-post-title.
The #+URI property can be defined containing following parameters:
%y: year of creation date
%m: month of creation date
%d: day of creation date"

  (let* ((date-list (split-string creation-date "-"))
         uri)
    (setq uri (or (op/read-org-option "URI")
                  (concat "/blog/%y/%m/%d/" (convert-string-to-path title))))
    (format-spec uri `((?y . ,(car date-list))
                       (?m . ,(cadr date-list))
                       (?d . ,(caddr date-list))))))

(defun op/read-file-info ()
  "Read info of org file opened in current buffer, include:
<TODO>: seems other values are not used except tags and uri
1. creation date
2. modification date
3. tags (read from #+TAGS property)
4. uri (read from #+URI property)
5. title
Creation date will be firstly read from #+DATE defined in the file, if no date
info found, will be read from the file's last change date. However, it is
recommended to use #+DATE."

  (let* ((filename (buffer-file-name))
         (file-attrs (file-attributes filename))
         (fcdate (format-time-string "%Y-%m-%d" (nth 6 file-attrs)))
         (mdate (format-time-string "%Y-%m-%d" (nth 5 file-attrs)))
         (attr-plist `(:creation-date ,fcdate :mod-date ,mdate :tags nil))
         opt-plist tags cdate)

    (setq opt-plist (org-infile-export-plist))
    (setq cdate (plist-get opt-plist :date))
    (if (and cdate (not (string-match "%" cdate)))
        (plist-put attr-plist :creation-date cdate))
    (plist-put attr-plist :title (or (plist-get opt-plist :title)
                                     (file-name-sans-extension
                                      (file-name-nondirectory filename))))
    (setq tags (op/read-org-option "TAGS")) ; TODO customization
    (if tags
        (plist-put
         attr-plist :tags (delete "" (mapcar 'trim-string
                                             (split-string tags ":" t))))) ;; TODO customization
    (plist-put attr-plist :uri (op/generate-uri
                                (plist-get attr-plist :creation-date)
                                (plist-get attr-plist :title))))) ; TODO customization

(defun op/handle-modified-file (org-file-path pub-base-dir)
  "TODO: doc"

  (let* ((visiting (find-buffer-visiting org-file-path))
         file-buffer attr-plist pub-dir title tags uri pub-dir)

    (with-current-buffer (setq file-buffer
                               (or visiting (find-file org-file-path)))
      (setq attr-plist (op/read-file-info))
      (setq uri (plist-get attr-plist :uri))
      (setq pub-dir (file-name-as-directory
                     (concat (file-name-as-directory pub-base-dir)
                             (replace-regexp-in-string "\\`/" "" uri))))
      (unless (file-directory-p pub-dir)
        (mkdir pub-dir t))
      (op/export-as-html nil nil nil nil nil pub-dir))
    (or visiting (kill-buffer file-buffer))))

(defun op/handle-deleted-file (org-file-path)
  "TODO: add logic for this function, maybe a little complex."
  )

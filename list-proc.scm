;; list-proc.scm
;;
;; Copyright (c) 2022 Matthew R. Wette
;;
;; This library is free software; you can redistribute it and/or
;; modify it under the terms of the GNU Lesser General Public
;; License as published by the Free Software Foundation; either
;; version 2.1 of the License, or (at your option) any later version.
;;
;; This library is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; Lesser General Public License for more details.
;;
;; You should have received a copy of the GNU Lesser General Public License
;; along with this library; if not, see <http://www.gnu.org/licenses/>

(use-modules (system repl command))
(use-modules (ice-9 rdelim))
(use-modules (system vm program))
(use-modules ((srfi srfi-1) #:select (first last)))

(define (find-path filename)
  (if (char=? #\/ (string-ref filename 0))
      filename
      (let loop ((dirs %load-path))
        (cond
         ((null? dirs) #f)
         ((access? (string-append (car dirs) "/" filename) R_OK)
          (string-append (car dirs) "/" filename))
         (else (loop (cdr dirs)))))))

(define-meta-command ((list-procedure extra) repl proc . args)
  "list-procedure proc
List procedure.

Show lines around current instruction address."
  (let* ((prog (module-ref (current-module) proc))
	 (srcs (program-sources-pre-retire prog))
	 (filename (source:file (car srcs)))
	 (lines (map source:line srcs))
	 (first-line (apply min lines))
	 (last-line (apply max lines))
	 (path (find-path filename)))
    (call-with-input-file path
      (lambda (port)
	(let loop ((lineno 0) (line (read-line port)))
	  (cond
	   ((< lineno first-line) (loop (1+ lineno) (read-line port)))
	   ((> lineno last-line))
	   (else
	    (display line) (newline)
	    (loop (1+ lineno) (read-line port)))))))))
	    
;; --- last line ---

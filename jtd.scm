;; jtd - jump to debugger
;;
;; Copyright (c) 2017-2018,2022 Matthew R. Wette
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

;;; Notes
;;
;; still beta -- not stable
;;
;; usage:
;; $ cat > foo.scm
;;   (define (foo)
;;      ....
;;      (if odd-behavior (jump-to-debugger))
;;      ...)
;; $ guild compile -O0 foo.scm
;; $ guile
;; > (load "foo.scm")
;; > (foo)
;; foo.scm: line 11
;;    (prev-line-of-code 1)
;; *  (if odd-behavior (jump-to-debugger))
;;    (next-line-of-code 1)
;; [1]>
;;
;; probably requires at least guile 3.0.0

;; todo:
;; 1) saved-ports (see error-handling.scm)
;; 2) emacs and/or geiser integration

;;; Code

(define-module (jtd) 
  #:export (jump-to-debugger kill-opt))

(use-modules (system base compile))

(use-modules (system repl command))
(use-modules (system repl common))
(use-modules (system repl debug))

(use-modules (system vm frame))
(use-modules (system vm program))
(use-modules (system vm traps))
(use-modules (system vm trap-state))
(use-modules (system vm vm))

(use-modules (ice-9 control))
(use-modules (ice-9 rdelim))

(define (sf fmt . args) (apply simple-format #t fmt args))

;;(define repl-next-resumer (@@ (system repl command) repl-next-resumer))
(define the-trap-state (@@ (system vm trap-state) the-trap-state))
(define next-ephemeral-index! (@@ (system vm trap-state) next-ephemeral-index!))
(define add-trap-wrapper! (@@ (system vm trap-state) add-trap-wrapper!))
(define make-trap-wrapper (@@ (system vm trap-state) make-trap-wrapper))
(define source-string (@@ (system vm trap-state) source-string))
(define ephemeral-handler-for-index (@@ (system vm trap-state)
                                        ephemeral-handler-for-index))
(define trap-state->trace-level (@@ (system vm trap-state)
                                    trap-state->trace-level))

;; for development
#|
(use-modules (ice-9 pretty-print))
(define pp pretty-print)

(define handler-for-index (@@ (system vm trap-state) handler-for-index))
(define trap-state-wrappers (@@ (system vm trap-state) trap-state-wrappers))
|#

;; ============================================================================

(define* (my-repl-next-resumer msg)
  ;; Based on system/repl/command.scm(repl-next-resumer):  Capture the
  ;; dynamic environment.  The result is a procedure that takes a frame.
  (% (let ((stack (abort
                   (lambda (k)
                     ;; Call frame->stack-vector before reinstating the
                     ;; continuation, so that we catch the %stacks fluid
                     ;; at the time of capture.
                     (lambda (frame)
                       (k (frame->stack-vector frame)))))))
       (cond
        ((procedure? msg) (msg stack))
        ((string? msg) (format #t "~a~%" msg)))
       ((module-ref (resolve-interface '(system repl repl)) 'start-repl)
        #:debug (make-debug stack 0 msg)))))

(define* (add-my-ephemeral-stepping-trap!
          frame handler
          #:optional (trap-state (the-trap-state))
          #:key (into? #t) (instruction? #f) (line? #f))
  ;; Based on system/vm/trap-state.scm(add-ephemeral-stepping-trap!).
  ;; Code has been added to allow breaking at a difference source line.
  (define (wrap-predicate-according-to-into predicate)
    (if into?
        predicate
        (let ((fp (frame-address frame)))
          (lambda (f)
            (and (<= (frame-address f) fp)
                 (predicate f))))))

  (define (source=? a b)
    (if line?
        (or
         (and (not a) b)
         (and a (not b))
         (and (equal? (source:file a) (source:file b))
              (equal? (source:line a) (source:line b))))
        (equal? a b)))
  
  (let* ((source (frame-source frame))
         (idx (next-ephemeral-index! trap-state))
         (trap (trap-matching-instructions
                (wrap-predicate-according-to-into
                 (if instruction?
                     (lambda (f) #t)
                     (lambda (f) (not (source=? (frame-source f) source)))))
                (ephemeral-handler-for-index trap-state idx handler))))
    (add-trap-wrapper!
     trap-state
     (make-trap-wrapper
      idx #t trap
      (if instruction?
          (if into?
              "Step to different instruction"
              (format #f "Step to different instruction in ~a" frame))
          (if into?
              (format #f "Step into ~a" (source-string source)) 
              (format #f "Step out of ~a" (source-string source))))))))

;; ============================================================================

(define (find-path filename)
  (if (char=? #\/ (string-ref filename 0))
      filename
      (let loop ((dirs %load-path))
        (cond
         ((null? dirs) #f)
         ((access? (string-append (car dirs) "/" filename) R_OK)
          (string-append (car dirs) "/" filename))
         (else (loop (cdr dirs)))))))

;; get a few lines from file
(define (get-lines filename lineno)
  (call-with-input-file (find-path filename)
    (lambda (port)
      (let loop ((prev #f) (curr #f) (offs lineno))
        (case offs
          ((1) (loop (cons " " (read-line port)) curr (1- offs)))
          ((0) (loop prev (cons "*" (read-line port)) (1- offs)))
          ((-1) (list prev curr (cons " " (read-line port))))
          (else (read-line port) (loop prev curr (1- offs))))))))

(define* (show-source-location source #:optional (port #t))
  (let ((file (cadr source))
        (line (caddr source)))
    (simple-format port "~A: line ~S\n" file (1+ line))
    (for-each
     (lambda (pair)
       (if pair
	   (simple-format port "~A ~A\n" (car pair) (cdr pair))))
     (get-lines file line))))

(define (format-source-location source)
  (let ((port (open-output-string)))
    (show-source-location source port)
    (get-output-string port)))
    
(define (show-from-stack stack)
  (if (positive? (vector-length stack))
      (let* ((frame (vector-ref stack 0))
             (source (frame-source frame)))
        (show-source-location source))))

;; ============================================================================

(define-meta-command ((next-line debug) repl)
  "next-line
Step until control reaches a different source location in the current frame.

Step until control reaches a different source location in the current frame."
  (let* ((debug (repl-debug repl))
         (index (debug-index debug))
         (frames (debug-frames debug)))
    (when (> (vector-length frames) index)
      (add-my-ephemeral-stepping-trap!
       (vector-ref frames index) (my-repl-next-resumer show-from-stack)
       #:into? #f #:instruction? #f #:line? #t)
      (set-vm-trace-level! (trap-state->trace-level (the-trap-state))))
    (throw 'quit)))

(define-meta-command ((list extra) repl)
  "list

Show lines around current instruction address."
  (and=>
   (repl-debug repl)
   (lambda (debug)
     (let* ((index (debug-index debug))
	    (frames (debug-frames debug))
	    (frame (vector-ref frames index)))
       (and=> (frame-source frame) show-source-location)))))

;; ============================================================================

(define (jump-to-debugger)
  (if (not (eq? 'debug (vm-engine)))
      (set-vm-engine! 'debug))

  ;; kludge to avoid welcome message in script usage:
  (unless (pair? (fluid-ref *repl-stack*))
    (fluid-set! *repl-stack* (list (make-repl (current-language)))))
  
  (catch 'quit ;; needed?
    (lambda ()
      ;; See error-handling.scm(call-with-error-handling).
      (let* ((stack (narrow-stack->vector (make-stack #t) 3))
             (debug (make-debug stack 0 "jumped to debugger")))
        (show-source-location (frame-source (vector-ref stack 0)))
        ((@ (system repl repl) start-repl) #:debug debug)))
    (lambda (key . args)
      (sf "jtd: QUIT\n"))))


(define (kill-opt)
  (default-optimization-level 0))


;; --- last line ---

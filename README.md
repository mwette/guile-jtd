# guile-jtd
jump-to-debugger: like Python's pdb.set_trace(), but for Guile

The `(jtd)` module for Guile provides a procedure (jump-to-debugger) 
for escaping to the Guile REPL for the purpose of debugging code.  
It should be considered beta code, still under development.

When debugging Guile code, it is usally better to compile with 
optimization level 0. You can use
```
$ guild compile -O0 file
```
or
```
$ guile
> ,use (system base compile)
> (default-optimization-level 0)
```

# Usage in REPL
```
$ cat > foo.scm
(use-modules (jtd))
(define *a* (make-parameter 0))
(define (foo . args)
    (let* ((b (+ (*a*) 1))
           (c (+ (*a*) b 2)))
      (if (< c 4)
          (jump-to-debugger))
      (simple-format #t "foo a= ~S\n" (*a*))
      (simple-format #t "foo b= ~S\n" b)
      (simple-format #t "foo c= ~S\n" c)))
^D
$ guild compile -O0 foo.scm
...
$ guile
...
scheme@(guile-user)> (load "foo.scm")
scheme@(guile-user)> (foo)
foo.scm: line 7
        (if (< c 4)
*           (jump-to-debugger))
        (simple-format #t "foo a= ~S\n" (*a*))
scheme@(guile-user) [1]> ,next-line
foo.scm: line 8
            (jump-to-debugger))
*       (simple-format #t "foo a= ~S\n" (*a*))
        (simple-format #t "foo b= ~S\n" b)
scheme@(guile-user) [1]> ,next-line
foo.scm: line 9
        (simple-format #t "foo a= ~S\n" (*a*))
*       (simple-format #t "foo b= ~S\n" b)
        (simple-format #t "foo c= ~S\n" c)))
scheme@(guile-user) [1]> ,next-line
foo b= 1
foo.scm: line 10
        (simple-format #t "foo b= ~S\n" b)
*       (simple-format #t "foo c= ~S\n" c)))
  #<eof>
scheme@(guile-user) [1]> ,next-line
foo c= 3
scheme@(guile-user) [1]> ,next-line
scheme@(guile-user)> 

```

# Usage in Scripts

This seems to work, but one must provide the `--debug` arg to `guile`.
```
$ guile --debug -e foo foo.scm
foo.scm: line 7
        (if (< c 4)
*           (jump-to-debugger))
        (simple-format #t "foo a= ~S\n" (*a*))
scheme@(guile-user) [1]> ,next-line
foo.scm: line 8
            (jump-to-debugger))
*       (simple-format #t "foo a= ~S\n" (*a*))
        (simple-format #t "foo b= ~S\n" b)
scheme@(guile-user) [1]> ,quit
foo b= 1
foo c= 3
```

# todo
1) saved-ports (see error-handling.scm)
2) emacs and/or geiser integration


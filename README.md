# guile-jtd
jump-to-debugger: like Python's pdb.set_trace(), but for Guile

The `(jtd)` module (jump to debugger) for Guile provides a procedure 
for escaping to the Guile REPL for the purpose of debugging code.  

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
foo.scm: line 4
  (define (foo . args)
*     (let* ((b (+ (*a*) 1))
             (c (+ (*a*) b 2)))
scheme@(guile-user) [1]> ,next-line
foo.scm: line 8
            (jump-to-debugger))
*       (simple-format #t "foo a= ~S\n" (*a*))
        (simple-format #t "foo b= ~S\n" b)
scheme@(guile-user) [1]> ,next-line
foo a= 0
foo.scm: line 4
  (define (foo . args)
*     (let* ((b (+ (*a*) 1))
             (c (+ (*a*) b 2)))
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

This works, but the repeated welcome messages can be annoying.
```
$ guile -e foo foo.scm
foo.scm: line 7
        (if (< c 4)
*           (jump-to-debugger))
        (simple-format #t "foo a= ~S\n" (*a*))
GNU Guile 3.0.7
Copyright (C) 1995-2021 Free Software Foundation, Inc.

Guile comes with ABSOLUTELY NO WARRANTY; for details type `,show w'.
This program is free software, and you are welcome to redistribute it
under certain conditions; type `,show c' for details.

Enter `,help' for help.
scheme@(guile-user)> ,next-line
foo.scm: line 4
  (define (foo . args)
*     (let* ((b (+ (*a*) 1))
             (c (+ (*a*) b 2)))
GNU Guile 3.0.7
Copyright (C) 1995-2021 Free Software Foundation, Inc.

Guile comes with ABSOLUTELY NO WARRANTY; for details type `,show w'.
This program is free software, and you are welcome to redistribute it
under certain conditions; type `,show c' for details.

Enter `,help' for help.
scheme@(guile-user)> ,next-line
foo.scm: line 8
            (jump-to-debugger))
*       (simple-format #t "foo a= ~S\n" (*a*))
        (simple-format #t "foo b= ~S\n" b)
GNU Guile 3.0.7
Copyright (C) 1995-2021 Free Software Foundation, Inc.

Guile comes with ABSOLUTELY NO WARRANTY; for details type `,show w'.
This program is free software, and you are welcome to redistribute it
under certain conditions; type `,show c' for details.

Enter `,help' for help.
scheme@(guile-user)> ,next-line
foo a= 0
foo.scm: line 4
  (define (foo . args)
*     (let* ((b (+ (*a*) 1))
             (c (+ (*a*) b 2)))
GNU Guile 3.0.7
Copyright (C) 1995-2021 Free Software Foundation, Inc.

Guile comes with ABSOLUTELY NO WARRANTY; for details type `,show w'.
This program is free software, and you are welcome to redistribute it
under certain conditions; type `,show c' for details.

Enter `,help' for help.
scheme@(guile-user)> 

```

# todo
1) saved-ports (see error-handling.scm)
2) emacs and/or geiser integration


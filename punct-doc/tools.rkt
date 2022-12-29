#lang racket/base

(require scribble/example
         scribble/manual)

(provide (all-defined-out))

(define (convert-newlines args)
  (map (λ (arg) (if (equal? arg "\n") (linebreak) arg)) args))

(define (repl-output . args)
  (nested (racketvalfont (tt (convert-newlines args)))))

(define (sandbox)
  (make-base-eval #:lang 'racket/base))


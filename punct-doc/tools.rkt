#lang racket/base

(require scribble/core
         scribble/example
         scribble/html-properties
         scribble/manual)

(provide (all-defined-out))

(define (convert-newlines args)
  (map (λ (arg) (if (equal? arg "\n") (linebreak) arg)) args))

(define (repl-output . args)
  (nested (racketvalfont (tt (convert-newlines args)))))

(define (sandbox)
  (make-base-eval #:lang 'racket/base))

(define (youtube-embed-element src)
  (element
   (make-style
   "youtube-embed"
   (list
    (make-alt-tag "iframe")
    (make-attributes `((width           . "700")
                       (height          . "394")
                       (src             . ,src)
                       (frameborder     . "0")
                       (allowfullscreen . "")))))
   ""))
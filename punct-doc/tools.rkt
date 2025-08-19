#lang racket/base

(require racket/runtime-path
         scribble/core
         scribble/example
         scribble/html-properties
         scribble/latex-properties
         scribble/manual)

(provide (all-defined-out))

(define-runtime-path aux-css "styles/my.css")
(define-runtime-path aux-tex "styles/my.tex")

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

(define (callout . args)
  (paragraph (style "callout" (list (color-property (list #x01 #x46 #x6c))
                                    (css-style-addition aux-css)
                                    (alt-tag "div")
                                    (tex-addition aux-tex)))
             args))
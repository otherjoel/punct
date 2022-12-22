#lang racket/base

(provide get-doc)

(define (get-doc src)
  (unless (file-exists? src)
    (raise-argument-error 'get-doc "path to existing file" src))
  (dynamic-require src 'doc))
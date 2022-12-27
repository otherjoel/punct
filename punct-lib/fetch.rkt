#lang racket/base

(require "doc.rkt")

(provide get-doc
         get-doc-ref)

(define (get-doc src [caller 'get-doc])
  (unless (file-exists? src)
    (raise-argument-error 'get-doc "path to existing file" src))
  (dynamic-require src 'doc))

(define (get-doc-ref src key)
  (hash-ref (document-metas (get-doc src 'get-doc-ref)) key #f))
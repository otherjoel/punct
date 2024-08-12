#lang racket/base

(require "doc.rkt"
         racket/match)

(provide get-doc
         get-meta
         meta-ref)

(define (get-doc src [caller 'get-doc])
  (unless (file-exists? src)
    (raise-argument-error 'get-doc "path to existing file" src))
  (dynamic-require src 'doc))

(define (get-meta doc k [default (λ ()
                                   (define path (hash-ref (document-metas doc) 'here-path))
                                   (error 'get-meta "key ~s not found\n  document: ~a" k path))])
  (hash-ref (document-metas doc) k default))

(define (meta-ref doc k) (get-meta doc k #f))
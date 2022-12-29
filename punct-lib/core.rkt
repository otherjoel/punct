#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

;; Core functions used by #lang punct sources

(require (for-syntax racket/base racket/sequence)
         "doc.rkt"
         "private/tsexp.rkt")
(provide attr-ref
         (all-defined-out)
         (all-from-out "doc.rkt"))

(define current-metas (make-parameter #f))

(define (set-meta k v)
  (current-metas (hash-set (current-metas) k v)))

;; Shorthand macro for defining multiple metas
(define-syntax (? stx)
  (syntax-case stx ()
    [(_ . KEYSVALS)
     (begin
       (unless (even? (length (syntax->datum #'KEYSVALS)))
         (raise-argument-error 'metas "equal number of keys and values" (syntax->datum #'KEYSVALS)))
       (with-syntax
           ([(KVS ...)
             (for/list ([k/v (in-syntax #'KEYSVALS)] [i (in-naturals)])
               (if (even? i) `',k/v k/v))])
         #'(current-metas (hash-set* (current-metas) KVS ...))))]))

(define (update-meta key proc default)
  (let ([updated (proc (hash-ref (current-metas) key default))])
    (set-meta key updated)))

(define (cons-to-metas-list key val)
  (define consed (cons val (hash-ref (current-metas) key '())))
  (current-metas (hash-set (current-metas) key consed)))

(define (update-metas-subhash key subkey val [proc (λ (v) v)])
  (define metas (current-metas))
  (define subhash (hash-ref metas key hasheq))
  (set-meta key (hash-set subhash subkey (proc val))))

(define (get-metas-subhash key subkey)
  (hash-ref (hash-ref (current-metas) key #hasheq()) subkey #f))


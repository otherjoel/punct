#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

#| “Tagged S-expressions”
   are like tagged x-expressions, in that they are lists that begin with a
   symbol, and whose second element may be a list of attributes (key/value
   pairs whose key is a symbol). But tagged s-expressions do not restrict
   attribute values to strings, and their elements can be literally anything.
|#

(require racket/match)

(provide (all-defined-out))

(define (attr? v)
  (and (list? v)
       (symbol? (car v))
       (not (null? (cdr v)))
       (null? (cddr v))))

(define (safe-attr? v)
  (and (list? v)
       (symbol? (car v))
       (not (null? (cdr v)))
       (null? (cddr v))
       (string? (cadr v))))

(define (attr-ref v key)
  (match v
    [(list-no-order (list (== key) val) attrs ...) val]
    [_ #f]))

(define (tsexpr->values lst)
  (match lst
    [(list* (? symbol? tag) (list (? attr? attrs) ...) elems)
     (values tag attrs elems)]
    [(list* (? symbol? tag) elems)
     (values tag '() elems)]))
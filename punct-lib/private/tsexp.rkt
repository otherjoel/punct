#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

#| “Tagged S-expressions”
   are like tagged x-expressions, in that they are lists that begin with a
   symbol, and whose second element may be a list of attributes (key/value
   pairs whose key is a symbol). But tagged s-expressions do not restrict
   attribute values to strings, and their elements can be literally anything.
|#

(require racket/match
         txexpr)

(provide (all-defined-out))
(provide txexpr)

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

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Match expander

(require (for-syntax racket/base
                     racket/match
                     racket/symbol
                     txexpr))

;; A match expander for txexprs that allows matching optional attributes
;; Example:
;;  (tx* 'img (id desc?) elems)
;; will match 'img txexpr with just id attribute, or both id and desc attributes, but not without id
(define-match-expander tx*
  (lambda (stx)
    (syntax-case stx ()
      [(_ tag-pat (attr ...) elem-pat)
       (with-syntax ([(hash-key ...)
                      (map maybe-optional-key (syntax->list #'(attr ...)))])
         #'(txexpr tag-pat (app attrs->hash (hash* hash-key ...)) elem-pat))]
      [(_ tag-pat elem-pat)
       #'(txexpr tag-pat _ elem-pat)])))

;; Converts identifiers into hash* match patterns
;; id → ['id id]
;; id? → ['id id #:default #f]
(define-for-syntax (maybe-optional-key stx)
  (match (symbol->immutable-string (syntax->datum stx))
    [(regexp #rx"^(.+)\\?$" (list _ attr-str))
     (with-syntax ([attr (datum->syntax stx (string->symbol attr-str) stx)])
       #'['attr attr #:default #f])]
    [_ #`['#,stx #,stx]]))

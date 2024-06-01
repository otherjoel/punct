#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

(require racket/match
         txexpr)

(provide (all-defined-out))
(provide txexpr)

(define (->string v)
  (cond
    [(string? v) v]
    [(or (symbol? v) (number? v) (boolean? v) (char? v) (path? v)) (format "~a" v)]
    [(or (null? v) (void? v)) ""]
    [else (format "~v" v)]))

(define (->safe-attr a)
  `(,(car a) ,(->string (cadr a))))

;; “Quasi” here signifies intentional laziness. These are quick resemblence checks, not
;; rigorous recursive validation.
(define (quasi/txexpr? v)   
  (and (list? v)
       (symbol? (car v))))

(define (quasi/attr? v)
  (and (list? v)
       (symbol? (car v))
       (not (null? (cdr v)))
       (null? (cddr v))))

(define (ref-attr attrs v)
  (match (assoc v attrs)
    [(list key val) val]
    [_ #f]))

(define (quasi/txexpr->values lst)
  (match lst
    [(list* (? symbol? tag) (list (? quasi/attr? attrs) ...) elems)
     (values tag (map ->safe-attr attrs) elems)]
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

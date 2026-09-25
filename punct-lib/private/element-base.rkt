#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

(require (for-syntax racket/base
                     racket/match
                     racket/symbol)
         racket/match)

(provide (all-defined-out))

(define (->string v)
  (cond
    [(string? v) v]
    [(or (symbol? v) (number? v) (boolean? v) (char? v) (path? v)) (format "~a" v)]
    [(or (null? v) (void? v)) ""]
    [else (format "~v" v)]))

(define (element? v)
  (and (pair? v)
       (symbol? (car v))
       (list? v)))

(define (attr? v)
  (and (attr-shaped? v)
       (string? (cadr v))))

(define (attr-shaped? v)
  (and (list? v)
       (not (null? v))
       (symbol? (car v))
       (not (null? (cdr v)))
       (null? (cddr v))))

(define (ref-attr attrs key [default #f])
  (match (assq key attrs)
    [(list _ val) val]
    [_ default]))

(define (set-attr attrs key val)
  (if (assq key attrs)
      (for/list ([a (in-list attrs)])
        (if (eq? (car a) key) (list key val) a))
      (append attrs (list (list key val)))))

(define (remove-attr attrs key)
  (filter (λ (a) (not (eq? (car a) key))) attrs))

(define (element-parts x)
  (match x
    [(list* tag (list (? attr? attrs) ...) kids) (values tag attrs kids)]
    [(list* tag kids) (values tag '() kids)]))

(define (make-element tag [attrs '()] [kids '()])
  (if (null? attrs)
      (cons tag kids)
      (list* tag attrs kids)))

(define (element-tag x) (car x))

(define (element-attrs x)
  (define-values (_tag attrs _kids) (element-parts x))
  attrs)

(define (element-children x)
  (define-values (_tag _attrs kids) (element-parts x))
  kids)

(define (element-map f x)
  (cond
    [(element? x)
     (define-values (tag attrs kids) (element-parts x))
     (f (make-element tag attrs (for/list ([k (in-list kids)]) (element-map f k))))]
    [else (f x)]))

(define (element-find pred x)
  (let/ec return
    (element-walk (λ (e) (when (pred e) (return e))) x)
    #f))

(define (element-find* pred x)
  (define found '())
  (element-walk (λ (e) (when (pred e) (set! found (cons e found)))) x)
  (reverse found))

(define (element-walk proc x)
  (when (element? x)
    (proc x)
    (for ([k (in-list (element-children x))])
      (element-walk proc k))))

(define (attrs->hash attrs)
  (for/hasheq ([kvpair (in-list (reverse attrs))])
    (apply values kvpair)))

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Match expanders

(define-match-expander element
  (λ (stx)
    (syntax-case stx ()
      [(_ tag-pat attrs-pat kids-pat)
       #'(? element?
            (app (λ (v) (call-with-values (λ () (element-parts v)) list))
                 (list tag-pat attrs-pat kids-pat)))])))

;; An element pattern that binds attributes by name, some of them optional
;; Example:
;;  (element* 'img (id desc?) elems)
;; will match 'img element with just id attribute, or both id and desc attributes, but not
;; without id.
(define-match-expander element*
  (λ (stx)
    (syntax-case stx ()
      [(_ tag-pat (attr ...) elem-pat)
       (with-syntax ([(hash-key ...)
                      (map maybe-optional-key (syntax->list #'(attr ...)))])
         #'(element tag-pat (app attrs->hash (hash* hash-key ...)) elem-pat))]
      [(_ tag-pat elem-pat)
       #'(element tag-pat _ elem-pat)])))

;; Converts identifiers into hash* match patterns
;; id → ['id id]
;; id? → ['id id #:default #f]
(define-for-syntax (maybe-optional-key stx)
  (match (symbol->immutable-string (syntax->datum stx))
    [(regexp #rx"^(.+)\\?$" (list _ attr-str))
     (with-syntax ([attr (datum->syntax stx (string->symbol attr-str) stx)])
       #'['attr attr #:default #f])]
    [_ #`['#,stx #,stx]]))

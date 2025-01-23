#lang racket/base

(require (for-syntax racket/base syntax/parse)
         "private/quasi-txpr.rkt"
         racket/match
         racket/string)

(provide default-element-function define-element)

(module elemrx racket/base
  (define element-id-rx #rx"^([^¶§\\.]+)(§|¶|)(\\..+|)$")
  (provide element-id-rx))

(require 'elemrx (for-syntax 'elemrx)) ; how to use the same value at phases 1 and 0

;; '([[class "x"]] 1 2 3) → (values '[[class "x"]] '(1 2 3))
;; '(1 2 3) → (values '() '(1 2 3))
(define (parse-leading-attrs elems)
  (match elems
    [(cons (list (? quasi/attr? attrs) ...) xprs) (values attrs xprs)]
    [else (values null elems)]))

;; '(#:class #:id) ("x" "y") → '((class "x") (id "y"))
(define (parse-kw-attrs kw-symbols-in kw-args)
  (define kw-symbols
    (map (λ (kw) (string->symbol (string-trim (keyword->string kw) "#:"))) kw-symbols-in))
  (map list kw-symbols kw-args))

;; (Symbol [#:Keyword String ...])
;;   → (λ ([#:Keyword String ...] . elements) → '(Symbol [[Symbol String] ...] elements ...)
(define default-element-function
  (make-keyword-procedure
   (λ (init-kws init-kw-args . args)
     (define id (car args))
     (define-values (tag kws+vals) (parse-id id))
     (define default-kws* (append init-kws (car kws+vals)))
     (define default-kwargs* (append init-kw-args (cadr kws+vals)))
     (define _element-function
       (make-keyword-procedure
        (λ (inner-kws inner-kw-args . xs)
          (let*-values ([(leading-attrs xs) (parse-leading-attrs xs)]
                        [(kw-attrs) (parse-kw-attrs (append default-kws* inner-kws)
                                                    (append default-kwargs* inner-kw-args))])
            (cons tag (match (append kw-attrs leading-attrs)
                        [(== null) xs]
                        [attrs (cons attrs xs)]))))))
     (procedure-rename _element-function id))))

;; 'aside¶.info → (values 'aside ((#:block #:class) ("single" "info")) )
(define (parse-id id)
  (match (regexp-match element-id-rx (symbol->string id))
    [(list _ id-str blockmark class-str)
     (define maybe-class
       `(#:class ,(if (non-empty-string? class-str)
                      (string-normalize-spaces class-str ".")
                      #f)))
     (define maybe-block
       `(#:block
         ,(match blockmark
            ["¶" "single"]
            ["§" "root"]
            [_ #f])))
     (define kws+vals
       (for/fold ([kws '()]
                  [vals '()]
                  #:result (list kws vals))
                 ([attr (in-list (list maybe-class maybe-block))]
                  #:when (cadr attr))
         (values (cons (car attr) kws) (cons (cadr attr) vals))))
     (values (string->symbol id-str) kws+vals)]
    [_ (error "Bad ID")]))

(define-for-syntax (get-id tag)
  (string->symbol (cadr (regexp-match element-id-rx (symbol->string tag)))))

(define-syntax (define-element stx)
  (syntax-parse stx
    [(_ TAG:id (~optional (~seq (~seq attr:keyword val:string) ...)))
     (with-syntax ([id (datum->syntax #'TAG (get-id (syntax->datum #'TAG)))])
       #'(define id (default-element-function 'ID (~? (~@ (~@ attr val) ...)))))]
    [(_ ID:id TAG:id (~optional (~seq (~seq attr:keyword val:string) ...)))
     #'(define ID (default-element-function 'TAG (~? (~@ (~@ attr val) ...))))]))

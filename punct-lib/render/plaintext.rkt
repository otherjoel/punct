#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

;; Renders punct documents to plain text

(require "base.rkt"
         net/uri-codec
         racket/class
         racket/format
         racket/list
         racket/match
         racket/string
         threading
         (only-in xml xexpr->string))

(provide doc->plaintext
         make-plaintext-fallback)

(define ($+ . vals)
  (string-append*
   (for/list ([v (in-list vals)])
     (cond [(list? v) (string-append* v)]
           [(string? v) v]
           [else (~a v)]))))

(define (prefix+joiner p)
  (lambda (lst) (string-append p (string-join lst #:after-last "\n"))))

(define (wrap-text content width #:line-prefix [$prefix #f]
                   #:first-line-prefix [first-prefix #f]
                   #:break-after? [break? #t])
  (define lst-c (if (list? content) content (list content)))
  (define words (string-split (string-append* lst-c)))
  (define lines
    (let loop ([current-line '()]
               [lines '()]
               [remaining-width width]
               [w words])
      (cond
        [(null? w) (reverse (cons (reverse current-line) lines))]
        [else
         (let* ([word (car w)]
                [len (string-length word)])
           (if (> len remaining-width)
               (loop (list word) (cons (reverse current-line) lines) (- width len 1) (cdr w))
               (loop (cons word current-line) lines (- remaining-width len 1) (cdr w))))])))
  (define prefix
    (match (list $prefix first-prefix)
      [(list #f (not #f)) (make-string (string-length first-prefix) #\space)]
      [(list (not #f) _) $prefix]
      [_ ""]))
  ($+
   (cond
     [first-prefix 
      (cons ((prefix+joiner first-prefix) (car lines)) (map (prefix+joiner prefix) (cdr lines)))]
     [else
      (map (prefix+joiner prefix) lines)])
   (if break? "\n" "")))

(define punct-plaintext-render%
  (class punct-abstract-render%
    (init line-width)
    (define width line-width)
    (define inset-width (inexact->exact (floor (* width .75))))
    (define/override (render-document)
      (define-values [body-strs footnote-strs] (super render-document))
      (define body (string-append* body-strs))
      (if (null? footnote-strs)
          body
          (string-append* body
                          "--------------------\nFootnotes:\n\n"
                          footnote-strs)))
    
    (define/override (render-heading level elems)
      (define heading-str (string-append* elems))
      (format "~a\n~a\n\n"
              heading-str
              (make-string (string-length heading-str) (if (equal? level "1") #\= #\-))))
    
    (define/override (render-thematic-break)
      ($+ (make-string 20 #\-) "\n\n"))
    
    (define/override (render-paragraph content)
      (wrap-text content width))
    
    (define/override (render-blockquote blocks)
      (wrap-text blocks inset-width #:line-prefix "  > "))

    (define/override (render-code-block info elems)
      ($+ (map (λ (s) (format "    ~a\n" s))
               (string-split (string-append* elems) "\n"))
          "\n"))

    (define/override (render-itemization style start elems)
      (string-append*
       (if (equal? start (~a #f))
           (map (λ (e) (wrap-text e width #:first-line-prefix " * ")) elems)
           (for/list ([item (in-list elems)] [i (in-naturals 1)])
             (wrap-text item width #:first-line-prefix (format "~a. " i))))))

    (define/override (render-item elems) ($+ elems))
    (define/override (render-bold elems) ($+ "**" elems "**"))
    (define/override (render-italic elems) ($+ "_" elems "_"))
    (define/override (render-code elems) ($+ "`" elems "`"))
    (define/override (render-link dest title elems)
      ($+ elems " (" dest ") "))

    (define/override (render-image src title desc elems)
      (format "(Image: ~a)\n\n" desc))
    (define/override (render-line-break) "\n")

    (define/override (render-html-block elem) ($+ elem "\n\n"))
    (define/override (render-html elem) elem)
    
    (define/override (render-footnote-reference label defnum refnum)
      (format "(~a)" defnum))

    (define footnote-count 1)
    (define/override (render-footnote-definition label refcount elems)
      (begin0
        (format "~a. ~a" footnote-count (string-append* elems))
        (set! footnote-count (add1 footnote-count))))
    
    (super-new)))

(define (make-plaintext-fallback width)
  (λ (tag attrs elems)
    (wrap-text (cons (format "[~a] " tag) elems) width)))

(define (doc->plaintext doc width [fallback (make-plaintext-fallback width)])
  (send (new punct-plaintext-render% [doc doc] [line-width width] [render-fallback fallback]) render-document))

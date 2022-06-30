#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

(require "tsexp.rkt"
         racket/list
         racket/match
         racket/string
         xml)

#| Flatpacking

…is my term for taking a (possibly nested) list and disassembling it into a flat structure in
a way that can survive some transformation, and so that the the original list can be reassembled
later. Here the transformation is the CommonMark parsing step.

 1: Initial                                2: Flatpack/concat                   
+------------------------+                +---------------------------+         
| # Heading              |                | # Heading                 |         
|                        |                |                           |         
|Hi!                     |                |Hi!                        |         
|                        |                |                           |         
|> A blockquote          | String         |> A blockquote             |         
|                        | content        |                           |         
+------------------------+                |<attrib block="yes">       | String   
|'(attrib [[block "yes"]]|         ===>   |                           | content  
|  "Buster Jones[^1]")   | List           |Buster Jones[^1]           |         
+------------------------+                |                           |         
|                        |                |</attrib>                  |         
|Last line.              |                |                           |         
|                        | String         |Last line.                 |         
|[^1]: Questionable      | content        |                           |         
+------------------------+                |[^1]: Questionable         |         
                                          +---------------------------+         
                                                                                
Converting s-expressions into HTMLish strings (“attrib”) in this example allows the contained
elements to be visible to the CommonMark parser.

After the CommonMark parse pass produces an AST, the HTMLish strings are preserved within 'html
and 'html-block elements, that can be matched up to reproduce the original s-expressions:

3: CommonMark parse pass                     4: Un-flatpacked                      
════════════════════════                     ════════════════                      
((heading 1 "Heading")                       ((heading 1 "Heading")                
 (para "Hi!")                                 (para "Hi!")                         
 (blockquote (para "A blockquote"))           (blockquote (para "A blockquote"))   
 (html-block "<attrib>")              ===>    (attrib                              
 (para                                          "Buster Jones"                     
   "Buster Jones"                               (footnote-ref "1"))                
   (footnote-ref "1"))                        (para "Last line."))                 
 (html-block "</attrib>")                    ((footnote-def "1" "Questionable"))   
 (para "Last line."))                                                              
((footnote-def "1" "Questionable"))                                                

|#

(provide flatpack reassemble-sexprs)

(define (push/first v lst) (cons (cons v (car lst)) (cdr lst)))
(define (push/rest v lst) (cons (cons v (cadr lst)) (cddr lst)))

(define (make-open/close-tags tag attrs)
  (let* ([strs (string-split (xexpr->string `(,tag ,attrs)) "><")]
         [opener (string-append (car strs) ">")]
         [closer (string-append "<" (cadr strs))])
    (values opener closer)))

;; Convert a tagged s-expression to a flat string
(define (flatpack xpr)
  (cond
    [(string? xpr) xpr]
    [else
     (define-values (tag attrs elems) (tsexpr->values xpr))
     (define-values (tag-open tag-close) (make-open/close-tags tag attrs))
     (define block-delim (if (assoc 'block attrs eq?) "\n\n" ""))
     (apply string-append `(,block-delim ,tag-open ,block-delim ,@(map flatpack elems) ,block-delim ,tag-close ,block-delim))]))

(define (html-delim? v)
  (and (list? v)
       (member (car v) '(html html-block))))

;; Return #t upon matching, e.g. '(html "<a href=\"...\"\>") and '(html "</a>")
(define (html-delimiter-match? open close)
  (with-handlers ([exn:fail? (λ (_) #f)])
    (car (string->xexpr (string-append (cadr open) (cadr close))))))

;; Synthesize a closing 'html x-expression for a given opening one
;; '(html "<a href='1.html'>) → '(html "</a>")
(define (synthesize-closer opener)
  (list 'html (format "</~a>" (cadr (regexp-match #rx"<([a-zA-Z]+)[ |>]" (cadr opener))))))

(define (assemble-sexpr opener maybe-closer elems)
  (define closer (or maybe-closer (synthesize-closer opener)))
  (define-values (tag attrs e) (tsexpr->values (string->xexpr (string-append (cadr opener) (cadr closer)))))
  ;; if this is a block-expression and the only element is a paragraph, shuck the paragraph
  (define new-elems
    (if (and (assoc 'block attrs eq?)
             (list? (car elems))
             (null? (cdr elems))
             (eq? (caar elems) 'paragraph))
        (cdr (car elems))     
        elems))
  (define new-attrs (filter-not (λ (v) (eq? 'block (car v))) attrs))
  `(,tag ,@(if (null? new-attrs) '() (list new-attrs)) ,@new-elems))

(define (reassemble-sexprs v)
  (cond
    [(not (list? v)) v]
    [else
     (let loop ([accum '()]
                [remain v]
                [in-tags '()]
                [inside '()])
       (match remain
         ['()
          (if (null? in-tags)
              (reverse accum)
              (loop (cons (assemble-sexpr (car in-tags) #f (reverse (car inside))) accum)
                    remain
                    (cdr in-tags)
                    (cdr inside)))]
         ; first elem is delimiter and matches current tag
         [(list* (? html-delim? closer) remaining)
          #:when (and (not (null? in-tags)) (html-delimiter-match? (car in-tags) closer))
          (define closed-lst (assemble-sexpr (car in-tags) closer (reverse (car inside))))
          (define nested? (not (null? (cdr in-tags))))
          (loop (if nested? accum (cons closed-lst accum))
                remaining
                (cdr in-tags)
                (if nested? (push/rest closed-lst inside) inside))]

         ; first elem is delimiter (& not a closing tag) → start a new list
         [(list* (? html-delim? opener) remaining)
          #:when (not (equal? "/" (substring (cadr opener) 1 2))) ;
          (loop accum
                remaining
                (cons opener in-tags)
                (cons '() inside))]
         [(list* (? html-delim? orphaned) remaining)
          (writeln (format "orphan: ~a" orphaned))
          (loop accum remaining in-tags inside)]
         ; first elem is a non-delimiter value and we are inside a tag
         [(list* v remaining)
          #:when (not (null? in-tags))
          (loop accum
                remaining
                in-tags
                (push/first (reassemble-sexprs v) inside))]
         [(list* v remaining)
          (loop (cons (reassemble-sexprs v) accum)
                remaining
                in-tags
                inside)]))]))
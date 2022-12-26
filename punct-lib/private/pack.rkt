#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

(require "constants.rkt"
         "tsexp.rkt"
         racket/format
         racket/list
         racket/match
         racket/string
         racket/symbol
         threading
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
|'(attrib [[block "yes"]]|         → → →  |                           | content  
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

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; We “mark” symbolic expressions by prefixing them, to keep them distinct from
;; any HTML strings originally present in the document.

(define mark-prefix "P1")
(define mark-html-regex (regexp (~a "<(?:/|)" mark-prefix ".*")))

;; 'tag 
(define (mark-tag t) (string->symbol (~a mark-prefix t)))
(define (unmark-tag t)
  (~> (symbol->immutable-string t)
      (string-trim mark-prefix #:right? #f)
      string->symbol))

(define (make-open/close-html-tags tag attrs)
  (let* ([strs (string-split (xexpr->string `(,(mark-tag tag) ,attrs)) "><")]
         [opener (~a (car strs) ">")]
         [closer (~a "<" (cadr strs))]
         [block-delim (if (equal? (attr-ref attrs 'block) punct-block-multi) "\n\n" "")])
    (values opener closer block-delim)))

;; Convert a tagged s-expression to a flat string
(define (flatpack v)
  (cond
    [(string? v) v]
    [(or (symbol? v) (number? v) (boolean? v) (char? v) (path? v)) (format "~a" v)]
    [(or (null? v) (void? v)) ""]
    [(and (list? v) (symbol? (car v)))
     (define-values (tag attrs elems) (tsexpr->values v))
     (unless (andmap safe-attr? attrs) (error 'punct "Attributes must be symbol-string pairs: ~a" attrs))
     (define-values (tag-open tag-close block-delim) (make-open/close-html-tags tag attrs))
     (string-append* `(,block-delim ,tag-open ,block-delim ,@(map flatpack elems) ,block-delim ,tag-close ,block-delim))]
    [(procedure? v) (error 'punct "Procedure ~a not a valid value" v)]
    [else (format "~v" v)]))

;; Return #t if v is a marked html delimiter
(define (html-delim? v)
  (match v
    [(list (or 'html 'html-block) (regexp mark-html-regex)) #t]
    [_ #f]))

;; Return #t upon matching, e.g. '(html "<a href=\"...\"\>") and '(html "</a>")
(define (html-delimiter-match? open close)
  (with-handlers ([exn:fail? (λ (_) #f)])
    (car (string->xexpr (string-append (cadr open) (cadr close))))))

;; Synthesize a closing 'html x-expression for a given opening one
;; '(html "<a href='1.html'>) → '(html "</a>")
(define (synthesize-closer opener)
  (list 'html (format "</~a>" (cadr (regexp-match #rx"<([a-zA-Z0-9]+)[ |>]" (cadr opener))))))

(define (assemble-sexpr opener maybe-closer elems)
  (define closer (or maybe-closer (synthesize-closer opener)))
  (define-values (ptag attrs e) (tsexpr->values (string->xexpr (string-append (cadr opener) (cadr closer)))))
  (define tag (unmark-tag ptag))
  ;; if this is a block-expression and the only element is a paragraph, shuck the paragraph
  (define new-elems
    (if (and (assoc 'block attrs eq?)
             (not (null? elems))
             (list? (car elems))
             (null? (cdr elems))
             (eq? (caar elems) 'paragraph))
        (cdr (car elems))     
        elems))
  (define new-attrs (filter-not (λ (v) (equal? `(block ,punct-block-multi) v)) attrs))
  `(,tag ,@(if (null? new-attrs) '() (list new-attrs)) ,@new-elems))


;; Performs Step 4 above: reassembling s-expressions within nested lists by
;; using HTML delimiters as delimiters.
(define (reassemble-sexprs v)
  (cond
    [(not (list? v)) v]
    [else
     (let loop ([accum '()]
                [remain v]
                [tag-stack '()]
                [nested-tag-stacks '()])
       (match remain
         ['()
          (if (null? tag-stack)
              (reverse accum)
              (loop (cons (assemble-sexpr (car tag-stack) #f (reverse (car nested-tag-stacks))) accum)
                    remain
                    (cdr tag-stack)
                    (cdr nested-tag-stacks)))]
         
         ; next elem is delimiter and matches current tag
         [(list* (? html-delim? closer) remaining)
          #:when (and (not (null? tag-stack)) (html-delimiter-match? (car tag-stack) closer))
          (define closed-lst (assemble-sexpr (car tag-stack) closer (reverse (car nested-tag-stacks))))
          (define nested? (not (null? (cdr tag-stack))))
          (loop (if nested? accum (cons closed-lst accum))
                remaining
                (cdr tag-stack)
                (if nested? (push/rest closed-lst nested-tag-stacks) nested-tag-stacks))]

         ; next elem is delimiter (& not a closing tag) → start a new list
         [(list* (? html-delim? opener) remaining)
          #:when (not (equal? "/" (substring (cadr opener) 1 2))) ;
          (loop accum
                remaining
                (cons opener tag-stack)
                (cons '() nested-tag-stacks))]

         ; next elem is a closing delimiter that had no opener (= no-op)
         [(list* (? html-delim? orphaned) remaining)
          (loop accum remaining tag-stack nested-tag-stacks)]
         
         ; next elem is a non-delimiter value and we are inside a tag
         [(list* v remaining)
          #:when (not (null? tag-stack))
          (loop accum
                remaining
                tag-stack
                (push/first (reassemble-sexprs v) nested-tag-stacks))]

         ; next elem is a non-delimiter value and we aren’t in a tag
         [(list* v remaining)
          (loop (cons (reassemble-sexprs v) accum)
                remaining
                tag-stack
                nested-tag-stacks)]))]))
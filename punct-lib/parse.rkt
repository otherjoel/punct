#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

;; Parsing utility functions for #lang punct

(require commonmark
         (prefix-in cm: commonmark/struct)
         commonmark/private/render
         "private/constants.rkt"
         "private/struct.rkt"
         "private/pack.rkt"
         racket/class
         racket/list
         racket/match)

(provide punct-debug
         parse-markup-elements)

(define punct-debug (make-parameter #f))

;;
;; ~~ Parsing functions ~~~~~~~~~~~~~~~~~~~~~~~~~~
;;

#| cm/punct-render%

A subclass of the abstract-render% class from commonmark/private/render that
simply renders the document to interpunct’s own document struct (see
private/struct for more info on the differences from the document struct
provided by commonmark).

Comments in commonmark/private/render indicate that abstract-render% is not
intended for public use “because some invariants are not checked”, but we
do so here anyways. All warnings given there apply, in particular that
instances of abstract-render% subclasses are stateful and should be discarded
after rendering a single document.
|#

(define cm/punct-render%
  (class abstract-render%
    (define/override (render-document)
      (define-values [body footnotes] (super render-document))
      (document (reassemble-sexprs body) (reassemble-sexprs footnotes)))
    
    (define/override (render-thematic-break)
      '(thematic-break))
    (define/override (render-heading content level)
      `(heading ([level ,level]) ,@content))
    (define/override (render-code-block content info)
      `(code-block ([info ,info]) ,content))
    (define/override (render-html-block content)
      `(html-block ,content))
    (define/override (render-paragraph content)
      `(paragraph ,@content))
    (define/override (render-blockquote blocks)
      `(blockquote ,@blocks))
    (define/override (render-itemization blockss style start-num)
      `(itemization ([style ,style] [start ,start-num])
                    ,@(for/list ([blocks (in-list blockss)]) `(item ,@blocks))))
    (define/override (render-line-break)
      '(line-break))
    (define/override (render-bold content)
      `(bold ,@content))
    (define/override (render-italic content)
      `(italic ,@content))
    (define/override (render-code content)
      `(code ,content))
    (define/override (render-link content dest title)
      `(link [[dest ,dest] [title ,title]] ,@content))
    (define/override (render-image desc src title)
      `(image ([src ,src] [title ,title] [desc ,desc])))
    (define/override (render-html content)
      `(html ,content))
    (define/override (render-footnote-reference label defn-num ref-num)
      `(footnote-reference ([label ,label] [defn-num ,defn-num] [ref-num ,ref-num])))
    (define/override (render-footnote-definition blocks label ref-count)
      `(footnote-definition ([label ,label] [ref-count ,ref-count]) ,@blocks))
    (super-new)))

(define (string->punct-doc str #:who [who 'string->punct-doc])
  ; CommonMark parsing pass
  (define intermediate-doc (string->document str)) 
  (when (punct-debug) (displayln intermediate-doc))

  ; Convert CommonMark struct to Punct struct and “unflatpack”.
  (send (new cm/punct-render% [doc intermediate-doc] [who who]) render-document))


;; Processes a list of elements into an punct document struct. If
;; extract-inline? is #t and the resulting doc contains only a single paragraph
;; and no footnotes, only the inline content of the paragraph is returned.
(define (parse-markup-elements elems
                               #:extract-inline? [extract-inline? #t]
                               #:parse-footnotes? [parse-fn? #f])
  ; “Flatpack” and “Concatenate” steps
  (define doc-string (splice/filter/pack elems))

  ;; CommonMark parsing and “Unflatpack” steps
  (define doc
    (parameterize ([current-parse-footnotes? parse-fn?])
      (string->punct-doc doc-string #:who 'parse-markup-elements)))
  
  (if extract-inline?
      (match doc
        [(document `((paragraph ,content)) '()) `(,punct-splicing-tag ,content)]
        [_ doc])
      doc))

;;
;; ~~ Private helpers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;

(define (splice x)
  (let loop ([x x])
    (if (list? x)
        (append-map
         (λ (x)
           (define proc (if (and (list? x) (not (null? x)) (eq? punct-splicing-tag (car x))) rest list))
           (proc (loop x)))
         x)
        x)))

;; Given a list of elements, removes empty lists and voids, splices the cdr
;; of any list beginning with the splicing tag into its surrounding lists,
;; converts all non-string element into serialized strings (including
;; “Flatpacking” — see pack.rkt), and concatenates the results into a single
;; string.
(define (splice/filter/pack lst)
  (apply string-append
         (for/list ([v (in-list (splice lst))]
                    #:unless (or (null? v) (void? v)))
           (cond
             [(string? v) v]
             [(or (symbol? v) (number? v) (boolean? v) (char? v) (path? v)) (format "~a" v)]
             [(and (list? v) (symbol? (car v))) (flatpack v)]
             [(procedure? v) (error 'punct "Procedure ~a not a valid value" v)]
             [else (format "~v" v)]))))
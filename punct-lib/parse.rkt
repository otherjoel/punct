#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

;; Parsing utility functions for #lang punct

(require "doc.rkt"
         commonmark
         (prefix-in cm: commonmark/struct)
         commonmark/private/render
         "private/constants.rkt"
         "private/pack.rkt"
         "private/quasi-txpr.rkt"
         racket/class
         (only-in racket/format ~a)
         racket/list
         racket/match
         threading)

(provide punct-debug
         parse-markup-elements
         splice)

(define punct-debug (make-parameter #f))

;;
;; ~~ Parsing functions ~~~~~~~~~~~~~~~~~~~~~~~~~~
;;

#| cm/punct-render%

A subclass of the abstract-render% class from commonmark/private/render that
simply renders the document to interpunct’s own document struct (see
private/doc for more info on the differences from the document struct
provided by commonmark).

Comments in commonmark/private/render indicate that abstract-render% is not
intended for public use “because some invariants are not checked”, but we
do so here anyways. All warnings given there apply, in particular that
instances of abstract-render% subclasses are stateful and should be discarded
after rendering a single document.
|#

(define cm/punct-render%
  (class abstract-render%
    (init metas)
    (define my-metas metas)
    (define/override (render-document)
      (define-values [body footnotes] (super render-document))
      (document my-metas
                (decode-single-blocks (reassemble-sexprs body))
                (decode-single-blocks (reassemble-sexprs footnotes))))
    (define/override (render-thematic-break)
      '(thematic-break))
    (define/override (render-heading content level)
      `(heading ([level ,(~a level)]) ,@content))
    (define/override (render-code-block content info)
      `(code-block ([info ,(or info "")]) ,content))
    (define/override (render-html-block content)
      `(html-block ,content))
    (define/override (render-paragraph content)
      `(paragraph ,@content))
    (define/override (render-blockquote blocks)
      `(blockquote ,@blocks))
    (define/override (render-itemization blockss style start-num)
      `(itemization ([style ,(~a style)] [start ,(if start-num (~a start-num) "")])
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
      `(link [[dest ,dest] [title ,(or title "")]] ,@content))
    (define/override (render-image desc src title)
      `(image ([src ,src] [title ,(or title "")] [desc ,desc])))
    (define/override (render-html content)
      `(html ,content))
    (define/override (render-footnote-reference label defn-num ref-num)
      `(footnote-reference ([label ,label] [defn-num ,(~a defn-num)] [ref-num ,(~a ref-num)])))
    (define/override (render-footnote-definition blocks label ref-count)
      `(footnote-definition ([label ,label] [ref-count ,(~a ref-count)]) ,@blocks))
    (super-new)))

(define (string->punct-doc str metas #:who [who 'string->punct-doc])
  (define intermediate-doc (string->document str))
  (send (new cm/punct-render% [metas metas] [doc intermediate-doc] [who who]) render-document))


;; Processes a list of elements into an punct document struct. If
;; extract-inline? is #t and the resulting doc contains only a single paragraph
;; and no footnotes, only the inline content of the paragraph is returned.
(define (parse-markup-elements metas elems
                               #:extract-inline? [extract-inline? #t]
                               #:parse-footnotes? [parse-fn? #f])
  (define doc
    (parameterize ([current-parse-footnotes? parse-fn?])
      (~> (splice elems)
          (map flatpack _)
          (apply string-append _)
          (string->punct-doc metas #:who 'parse-markup-elements))))
  
  (if extract-inline?
      (match doc
        [(document _ (list (list* paragraph content)) _) `(,punct-splicing-tag ,content)]
        [_ doc])
      doc))
 
;; '(1 (@ 2 (3 4)) 5) → '(1 2 (3 4) 5)
(define (splice x)
  (let loop ([x x])
    (if (list? x)
        (append-map
         (λ (x)
           (define proc (if (and (list? x) (not (null? x)) (eq? punct-splicing-tag (car x))) rest list))
           (proc (loop x)))
         x)
        x)))

;; '(paragraph (tag [[block "single"]] "hi")) → '(tag "hi")
(define (decode-single-blocks lst)
  (let loop ([x lst])
    (match x
      [(list 'paragraph (list (? symbol? tag) (list-no-order (list 'block blocktype) (? quasi/attr? attrs) ...) elems ...))
       #:when (equal? blocktype punct-block-single)
       `(,tag ,@(if (null? attrs) '() (list attrs)) ,@(map decode-single-blocks elems))]
      [(list* (? symbol? tag) (list (? quasi/attr? attrs) ...) elems)
       `(,tag ,attrs ,@(map decode-single-blocks elems))]
      [(list* (? symbol? tag) elems)
       `(,tag ,@(map decode-single-blocks elems))]
      [(? list?)
       (map decode-single-blocks x)]
      [_ x])))
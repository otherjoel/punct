#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

;; Renders punct documents to Typst markup

(require "base.rkt"
         "../doc.rkt"
         racket/class
         racket/format
         racket/match
         racket/string)

(provide punct-typst-render%
         doc->typst
         default-typst-tag
         escape-typst-text
         escape-typst-string)

;; Escape special Typst characters in text content
;; Uses Perl-compatible regex for proper character class handling
(define (escape-typst-text str)
  (if (string? str)
      (regexp-replace* #px"([*_`#@$\\[\\]\\\\])" str "\\\\\\1")
      str))

;; Escape characters in quoted string arguments (URLs, paths)
(define (escape-typst-string str)
  (if (string? str)
      (string-replace (string-replace str "\\" "\\\\") "\"" "\\\"")
      str))

;; Helper to join elements into a string
(define (join-elems elems)
  (string-append* (map ~a elems)))


;; Add paragraph break after block content
(define (block v)
  (~a v "\n\n"))

(define punct-typst-render%
  (class punct-abstract-render%
    (inherit-field doc)
    (super-new)

    ;; Build footnote lookup table: label -> (list of body elements)
    (define footnote-table
      (make-hash
       (for/list ([fn (in-list (document-footnotes doc))])
         (match fn
           [`(footnote-definition [[label ,label] [ref-count ,_]] . ,elems)
            (cons label elems)]))))

    ;; Override render-string to escape special Typst characters in raw text
    (define/override (render-string s)
      (escape-typst-text s))

    ;; Override render-document to return a string (not values)
    (define/override (render-document)
      (define-values [body-elems _footnotes] (super render-document))
      (string-append* body-elems))

    ;; Block-level elements

    (define/override (render-heading level elems)
      (block (~a (make-string (string->number level) #\=) " " (join-elems elems))))

    (define/override (render-thematic-break)
      (block "#line(length: 100%)"))

    (define/override (render-paragraph content)
      (block (join-elems content)))

    (define/override (render-blockquote blocks)
      (block (~a "#quote(block: true)[\n" (join-elems blocks) "]")))

    (define/override (render-code-block info elems)
      (define lang (if (non-empty-string? info) info ""))
      (block (~a "```" lang "\n" (join-elems elems) "\n```")))

    (define/override (render-itemization style start elems)
      (define tight? (equal? style "tight"))
      (define numbered? (non-empty-string? start))
      (define marker (if numbered? "+ " "- "))
      (define items
        (for/list ([elem (in-list elems)])
          (~a marker elem (if tight? "\n" "\n\n"))))
      (block (string-append* items)))

    (define/override (render-item elems)
      (join-elems elems))

    (define/override (render-html-block elem)
      ;; Pass through HTML verbatim - Typst will show as text
      (block elem))

    ;; Inline elements

    (define/override (render-bold elems)
      (~a "*" (join-elems elems) "*"))

    (define/override (render-italic elems)
      (~a "_" (join-elems elems) "_"))

    (define/override (render-code elems)
      (~a "`" (join-elems elems) "`"))

    (define/override (render-link dest title elems)
      (~a "#link(\"" (escape-typst-string dest) "\")[" (join-elems elems) "]"))

    (define/override (render-image src title desc elems)
      ;; Basic image; could be wrapped in figure for caption
      (~a "#image(\"" (escape-typst-string src) "\")"))

    (define/override (render-line-break)
      "\\\n")

    (define/override (render-html elem)
      ;; Pass through inline HTML verbatim
      elem)

    ;; Footnotes - rendered inline at reference point

    (define/override (render-footnote-reference label defnum refnum)
      ;; Look up footnote content and render inline
      (define fn-body (hash-ref footnote-table label '()))
      (define rendered-body (send this render-footnote-body fn-body))
      (~a "#footnote[" rendered-body "]"))

    (define/public (render-footnote-body elems)
      ;; Render footnote body elements
      ;; This needs to process the raw footnote elements
      (string-join
       (for/list ([elem (in-list elems)])
         (match elem
           [(? string?) (escape-typst-text elem)]
           [`(paragraph . ,content)
            (string-join (map (λ (e) (send this render-footnote-elem e)) content))]
           [_ (~a elem)]))
       " "))

    (define/public (render-footnote-elem elem)
      (match elem
        [(? string?) (escape-typst-text elem)]
        [`(bold . ,content)
         (~a "*" (string-join (map (λ (e) (send this render-footnote-elem e)) content)) "*")]
        [`(italic . ,content)
         (~a "_" (string-join (map (λ (e) (send this render-footnote-elem e)) content)) "_")]
        [`(code . ,content)
         (~a "`" (string-join (map (λ (e) (send this render-footnote-elem e)) content)) "`")]
        [`(link [[dest ,dest] . ,_] . ,content)
         (~a "#link(\"" (escape-typst-string dest) "\")[" (string-join (map (λ (e) (send this render-footnote-elem e)) content)) "]")]
        [_ (~a elem)]))

    (define/override (render-footnote-definition label refcount elems)
      ;; No-op: footnotes are rendered inline at reference points
      "")))

;; Main entry point
(define (doc->typst doc [fallback default-typst-tag])
  (send (new punct-typst-render% [doc doc] [render-fallback fallback])
        render-document))

;; Default handler for custom/unknown tags
(define (default-typst-tag tag attrs elems)
  (~a "#" tag "(" (if (null? elems) "" (join-elems elems)) ")"))

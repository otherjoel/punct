#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

;; Renders interpunct documents to HTML x-expressions

(require "../private/struct.rkt"
         "base.rkt"
         net/uri-codec
         racket/class
         racket/format
         racket/list
         racket/match
         threading
         (only-in xml xexpr->string))

(provide doc->html)

(define punct-html-render%
  (class punct-abstract-render%
    (define/override (render-document)
      (define-values [body footnotes] (super render-document))
      (if (null? footnotes)
          `(article ,@body)
          `(article ,@body (section [[class "footnotes"]] (ol ,@footnotes)))))
    
    (define/override (render-heading level elems)
      (define tag (string->symbol (~a "h" level)))
      `(,tag ,@elems))
    
    (define/override (render-thematic-break)
      '(hr))
    (define/override (render-paragraph content)
      `(p ,@content))
    (define/override (render-blockquote blocks)
      `(blockquote ,@blocks))
    (define/override (render-code-block info elems)
      `(pre (code ,@(if info `(((info ,(~a "language-" info)))) '()) ,@elems)))
    
    (define/override (render-itemization style start elems)
      (if (not start)
          `(ul ,@elems)
          `(ol [[start ,(~a start)]] ,@elems)))
    (define/override (render-item elems) `(li ,@elems))
    (define/override (render-bold elems) `(b ,@elems))
    (define/override (render-italic elems) `(i ,@elems))
    (define/override (render-code elems) `(code ,@elems))
    (define/override (render-link dest title elems)
      `(a [[href ,dest] ,@(if title `((title ,title)) '())] ,@elems))
    (define/override (render-image src title elems)
      `(img [[src ,src] ,@(if title `((title ,title)) '())]))
    (define/override (render-line-break) '(br))

    (define/override (render-html-block elem) elem)
    (define/override (render-html elem) elem)
    (define/override (render-other tag attrs elems)
      `(,tag ,@(if (null? attrs) '() (list attrs)) ,@elems))
    
    (define/override (render-footnote-reference label defnum refnum)
      `(sup (a [[href ,(~a "#" (fn-def-anchor label))]
                [id ,(fn-ref-anchor label refnum)]]
               ,(number->string defnum))))

    (define/override (render-footnote-definition label refcount elems)
      (define backrefs
        (~> (for/list ([n (in-range refcount)])
              (define refnum (add1 n))
              (define title (~a "Jump to reference"
                                   (if (> refcount 1) (format " (~a)" refnum) "")))
              `(a [[class "footnote-backref"]
                   [href ,(~a "#" (fn-ref-anchor label refnum))]
                   [title ,title]
                   [aria-label ,title]]
                  "↩"
                  ,@(if (> refcount 1) `((sup ,(~a refnum))) '())))
            (add-between " ")
            (cons " " _)))
      `(li [[id ,(fn-def-anchor label)]]
           ,@(match elems
               [(list blocks ... (list 'p inline ...)) `(,@blocks (p ,@inline ,@backrefs))]
               [_ (append elems backrefs)])))
           
    (define/public (fn-ref-anchor label refnum)
      (format "fnref_~a_~a" (uri-path-segment-encode label) refnum))
    (define/public (fn-def-anchor label)
      (format "fn_~a" (uri-path-segment-encode label)))
    
    (super-new)))

(define (doc->html doc)
  (xexpr->string (send (new punct-html-render% [doc doc]) render-document)))

#|   
    [(txexpr 'poetry attrs elems) (render-poetry attrs elems)]
    [(txexpr 'dialogue _ elems) `(dl ,@elems)]
    [(list 'speech interlocutor elems ...)
     `(@ (dt ,interlocutor (span [[class "x"]] ": ")) (dd ,@elems))]
    [(txexpr 'figure attrs elems) (render-figure (car elems) (cdr elems))]
    [else (fallback-proc v)]))
|#


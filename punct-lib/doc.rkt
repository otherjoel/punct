#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.
(require "private/quasi-txpr.rkt")

(provide (struct-out document) block-element? inline-element?)

#| Punct’s document structure is very similar to Commonmark’s,
   except that it is prefab and uses simple lists instead of
   structs. This makes it easier to add custom elements, and to
   serialize the document.

   Punct’s doc also includes a hash table for metadata.
|#

(struct document (metas body footnotes) #:prefab)

;; These functions are not actually used in punct-lib. They exist only to have some clear
;; predicates for use in the documentation.
;;
(define (block-element? v)
  (and (quasi/txexpr? v)
       (member (car v) '(heading
                         paragraph
                         itemization
                         item
                         blockquote
                         code-block
                         html-block
                         thematic-break
                         footnote-definition))
       #t))

(define (inline-element? v)
  (or (string? v)
      (and (quasi/txexpr? v)
           (not (block-element? v)))))
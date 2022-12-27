#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

(provide (struct-out document) meta-ref)

#| Punct’s document structure is very similar to Commonmark’s,
   except that it is prefab and uses simple lists instead of
   structs. This makes it easier to add custom elements, and to
   serialize the document.

   Punct’s doc also includes a hash table for metadata.
|#

(struct document (metas body footnotes) #:prefab)

(define (meta-ref doc key)
  (hash-ref (document-metas doc) key #f))

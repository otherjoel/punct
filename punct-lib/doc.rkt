#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

(provide (struct-out document) meta-ref)

#| Punct’s document struct
…is exactly like Commonmark’s except 1) it includes a hash table for metadata,
and 2) it is prefab so it can be serialized.
|#

(struct document (metas body footnotes) #:prefab)

(define (meta-ref doc key)
  (hash-ref (document-metas doc) key #f))

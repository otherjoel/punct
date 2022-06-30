#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

(provide (struct-out document))

#| Punct’s document struct
…is exactly like Commonmark’s except it is prefab so it can be serialized.

|#

(struct document (body footnotes) #:prefab)

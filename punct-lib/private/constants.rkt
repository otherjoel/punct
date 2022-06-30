#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

;; Library constants

(provide (prefix-out punct- (all-defined-out)))

(define command-char  #\•)
(define here-path-key 'here-path)
(define here-id-key   'here-id)
(define metas-id      'metas)
(define doc-id        'doc)
(define splicing-tag  '@)

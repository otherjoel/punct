#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.


(require racket/pretty)

;; These two bindings are used in the reader to ensure that when an Interpunct
;; is run as the top-level-module, its doc is displayed as output, but not
;; otherwise.
(provide current-top-path show)

(define current-top-path (make-parameter #f))

(define (show doc source-path)
  (when (equal? source-path (current-top-path))
    (pretty-print doc)))
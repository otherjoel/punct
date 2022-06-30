#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

;; Main module expander for #lang punct

(require (for-syntax "constants.rkt"
                     racket/base)
         (prefix-in doclang: "doclang-raw.rkt")
         "../core.rkt"
         "../parse.rkt"
         racket/class)

(provide punct-debug
         (except-out (all-from-out racket/base) #%module-begin)
         (rename-out [*module-begin #%module-begin]))

(define-syntax (*module-begin stx)
  (define prev-metas-id (gensym))
  (syntax-case stx ()
    [(_ INIT-METAS MODULES EXPRS ...)
     (with-syntax ([DOC punct-doc-id]
                   [METAS (datum->syntax stx punct-metas-id)]
                   [(METAS-KVS ...) (datum->syntax stx #'INIT-METAS)]
                   [PREV-METAS (datum->syntax stx prev-metas-id)]
                   [CORE (datum->syntax stx 'punct/core)]
                   [(EXTRA-MODULES ...) (datum->syntax stx #'MODULES)]
                   [ALL-DEFINED (datum->syntax stx '(all-defined-out))])
       #'(doclang:#%module-begin
          DOC
          (λ (xprs)
            (begin0 (parse-markup-elements xprs #:extract-inline? #f #:parse-footnotes? #t)
                    (set! METAS (current-metas))
                    (current-metas PREV-METAS)))
          (require CORE EXTRA-MODULES ...)
          (provide ALL-DEFINED)
          (define METAS (hasheq METAS-KVS ...))
          (define PREV-METAS (current-metas))
          (current-metas METAS)
          EXPRS ...))]))

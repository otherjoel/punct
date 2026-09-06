#lang racket/base
; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

;; Reader and indenter/color lexer for #lang punct

(module reader racket/base
  (require "private/constants.rkt"
           "private/reader-utils.rkt"
           scribble/reader
           syntax/strip-context)
  (provide get-info (rename-out [*read-syntax read-syntax]))

  (define read-punct-syntax
    (make-at-reader #:command-char punct-command-char
                    #:syntax? #t
                    #:inside? #t))
  
  (define (*read-syntax name inport)
    (port-count-lines! inport)
    (define source-path
      (format "~a" ((if (syntax? name) syntax-source values) name)))
    (define extra-modules (read-line-modpaths name inport))
    (define meta-kvs
      `(',punct-here-path-key ,source-path ,@(or (read-metas-block name inport) '())))
    (define exprs (read-punct-syntax name inport))

    (strip-context
     #`(module runtime-wrapper racket/base
         (module configure-runtime racket/base
           (require punct/private/configure-runtime)
           (current-top-path #,source-path))
         (module _punct-main punct/private/main
           #,meta-kvs
           #,extra-modules
           #,@exprs)
         (require '_punct-main (only-in punct/private/configure-runtime show))
         (provide (all-from-out '_punct-main))
         (show #,punct-doc-id #,source-path))))
  
  (define (get-info port src-mod src-line src-col src-pos)
    (λ (key default)
      (case key
        [(color-lexer)
         (with-handlers ([exn:missing-module? (λ (_) default)])
           (dynamic-require 'punct/private/color-lexer 'punct-color-lexer))]
        [(drracket:indentation)
         (with-handlers ([exn:missing-module?
                        (λ (x) (default key default))])
           (dynamic-require 'scribble/private/indentation 'determine-spaces))]
        [else default]))))
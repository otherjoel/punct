#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

;; Syntax-coloring lexer for #lang punct: the scribble-inside lexer, with its
;; text runs split on Markdown structure. Structural tokens carry a 'markup
;; attribute (heading emphasis strong code link list quote rule meta) beside a
;; standard 'type, so editors that know nothing of 'markup still color them.
;;
;; syntax-color is loaded dynamically so that punct-lib does not depend on it.

(require racket/port
         "constants.rkt")

(provide punct-color-lexer)

(define scribble-inside-lexer
  ((dynamic-require 'syntax-color/scribble-lexer 'make-scribble-inside-lexer)
   #:command-char punct-command-char))

;; ----------------------------------------------------------------------------
;; Mode: the inner lexer's mode plus the Markdown context at this position.
;; block is 'start while a metas block is still possible, 'metas inside one,
;; the opening fence string inside a code block, or #f; bol? is true at the
;; start of a line; heading? through the rest of a heading line; off counts
;; the characters since the current text run began.

(struct md (inner block bol? heading? off) #:transparent)

(struct tok (len type markup))

(define (punct-color-lexer in offset mode)
  (define-values (_line col pos) (port-next-location in))
  (define m (or mode (md #f 'start (eqv? col 0) #f 0)))
  (define fin (special-filter-input-port in (λ (v s) (bytes-set! s 0 (char->integer #\.)) 1)))
  (define pk (peeking-input-port fin #:init-position pos))
  (port-count-lines! pk)
  (define-values (lexeme attribs paren start end backup inner*)
    (scribble-inside-lexer pk offset (md-inner m)))
  (define len (- end start))
  (define text (peek-string len 0 fin))
  (define (emit n attribs backup mode)
    (read-string n fin)
    (values lexeme attribs paren start (+ start n) backup mode))
  (case (attrib-type attribs)
    [(eof) (values lexeme attribs paren start end backup #f)]
    [(text)
     (define-values (t block heading? bol?) (run-token text m))
     (define last? (= (tok-len t) len))
     (emit (tok-len t) (retag attribs t) (+ backup (md-off m))
           (md (if last? inner* (md-inner m)) block bol? heading?
               (if last? 0 (+ (md-off m) (tok-len t)))))]
    [(white-space)
     (define newline? (regexp-match? #rx"[\r\n]" text))
     (emit len attribs backup
           (md inner* (md-block m) newline? (and (not newline?) (md-heading? m)) 0))]
    [else
     (emit len attribs backup
           (md inner* (if (and (md-bol? m) (eq? (md-block m) 'start)) #f (md-block m))
               #f (md-heading? m) 0))]))

(define (attrib-type a) (if (hash? a) (hash-ref a 'type) a))

(define (retag attribs t)
  (define h (if (hash? attribs) attribs (hasheq 'type attribs)))
  (cond
    [(tok-markup t) (hash-set (hash-set h 'type (tok-type t)) 'markup (tok-markup t))]
    [(eq? (tok-type t) (attrib-type attribs)) attribs]
    [else (hash-set h 'type (tok-type t))]))

;; ----------------------------------------------------------------------------
;; The first token of a text run: (values token block heading? bol?), the
;; last three being the context after it. Later calls see the rest of the run
;; as a fresh run, so only the first token is ever needed; bol? stays true
;; after a list or quote marker, whose remainder is still block content.

(define rx:dashes   #px"^-{3,}\\s*$")
(define rx:fence    #px"^(`{3,}|~{3,})")
(define rx:close    #px"^([`~]+)\\s*$")
(define rx:heading  #px"^#{1,6}(?:\\s|$)")
(define rx:rule     #px"^([-*_])(?:\\s*\\1){2,}\\s*$")
(define rx:refdef   #px"^\\[[^\\]]+\\]:\\s*\\S")
(define rx:meta-key #px"^[^:\\s](?:[^:]*[^:\\s])?\\s*:\\s*")
(define rx:quote    #px"^>\\s?")
(define rx:list     #px"^(?:[-+*]|\\d{1,9}[.)])(?:\\s+|$)")

(define (run-token s m)
  (define block (md-block m))
  (define bol? (md-bol? m))
  (define (whole type markup) (tok (string-length s) type markup))
  (cond
    [(string? block)
     (values (whole 'string 'code) (if (and bol? (closes? s block)) #f block) #f #f)]
    [(eq? block 'metas)
     (cond
       [(and bol? (regexp-match? rx:dashes s)) (values (whole 'hash-colon-keyword 'meta) #f #f #f)]
       [(and bol? (regexp-match-positions rx:meta-key s))
        => (λ (p) (values (tok (cdar p) 'hash-colon-keyword 'meta) 'metas #f #f))]
       [else (values (whole 'text #f) 'metas #f #f)])]
    [(md-heading? m) (values (whole 'keyword 'heading) block #t #f)]
    [bol?
     (cond
       [(and (eq? block 'start) (regexp-match? rx:dashes s))
        (values (whole 'hash-colon-keyword 'meta) 'metas #f #f)]
       [(regexp-match rx:fence s) => (λ (f) (values (whole 'string 'code) (cadr f) #f #f))]
       [(regexp-match? rx:heading s) (values (whole 'keyword 'heading) #f #t #f)]
       [(regexp-match? rx:rule s) (values (whole 'parenthesis 'rule) #f #f #f)]
       [(regexp-match? rx:refdef s) (values (whole 'symbol 'link) #f #f #f)]
       [(marker s) => (λ (t) (values t #f #f #t))]
       [else (values (first-span s) #f #f #f)])]
    [else (values (first-span s) block #f #f)]))

(define (closes? s fence)
  (define m (regexp-match rx:close s))
  (and m
       (char=? (string-ref (cadr m) 0) (string-ref fence 0))
       (>= (string-length (cadr m)) (string-length fence))))

(define (marker s)
  (cond
    [(regexp-match-positions rx:quote s) => (λ (p) (tok (cdar p) 'parenthesis 'quote))]
    [(regexp-match-positions rx:list s) => (λ (p) (tok (cdar p) 'parenthesis 'list))]
    [else #f]))

;; ----------------------------------------------------------------------------
;; Inline spans. The alternation order puts strong before emphasis so ** wins
;; at a shared start, and a closing * must not begin a ** pair.

(define rx:inline
  (pregexp
   (string-append
    "(`+)(?:[^`]|(?!\\1)`)*?\\1"                                   ; code span
    "|\\*\\*(?=\\S)(?:[^*]|\\*(?!\\*))+?(?<=\\S)\\*\\*"             ; strong
    "|(?<!\\w)__(?=\\S)(?:[^_]|_(?!_))+?(?<=\\S)__(?!\\w)"
    "|\\*(?=[^\\s*])(?:[^*]|\\*\\*)*?(?<=[^\\s*])\\*(?!\\*)"          ; emphasis
    "|(?<!\\w)_(?=[^\\s_])(?:[^_]|__)*?(?<=[^\\s_])_(?!\\w)"
    "|!?\\[[^\\]]*\\](?:\\([^)]*\\)|\\[[^\\]]*\\])"                 ; link, image
    "|<(?:https?|mailto):[^>\\s]*>")))                              ; autolink

(define (inline-kind s)
  (cond
    [(char=? (string-ref s 0) #\`) (values 'string 'code)]
    [(regexp-match? #rx"^(\\*\\*|__)" s) (values 'text 'strong)]
    [(memv (string-ref s 0) '(#\* #\_)) (values 'text 'emphasis)]
    [else (values 'symbol 'link)]))

;; Plain text up to the first span, or the span itself when it starts the run
(define (first-span s)
  (define p (regexp-match-positions rx:inline s))
  (cond
    [(not p) (tok (string-length s) 'text #f)]
    [(> (caar p) 0) (tok (caar p) 'text #f)]
    [else
     (define-values (type markup) (inline-kind (substring s 0 (cdar p))))
     (tok (cdar p) type markup)]))

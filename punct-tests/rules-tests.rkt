#lang racket/base

(require rackunit
         punct/render/base
         punct/render/html
         punct/render/plaintext
         punct/render/typst
         racket/string)

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; HTML

(define-html-rules (render tag attrs elems)
  [(or meta unsubscribe) ""]
  [margin-note #:as aside.margin]
  [wide #:as div.wide.full-bleed]
  [said-by #:as dt]
  [(photo source ext [id #f]) #:when (equal? ext "avif")
   `(img [[src ,(format "/~a-1000.avif" source)] ,@(if id `([id ,id]) '())])]
  [(photo source ext)
   `(img [[src ,(format "/~a.~a" source ext)]])]
  [(note-card id title)
   `(section [[id ,id]] (h3 ,title) ,@elems)]
  [poetry
   (define n (length elems))
   `(div [[class "poem"] [data-lines ,(number->string n)]] ,@elems)])

;; #:as clauses
(check-equal? (render 'margin-note '([block "root"]) '("a" (b "c")))
              '(aside ([class "margin"]) "a" (b "c")))
(check-equal? (render 'wide '() '("x")) '(div ([class "wide full-bleed"]) "x"))
(check-equal? (render 'said-by '([block "root"]) '("Bob")) '(dt "Bob"))

;; (or tag ...)
(check-equal? (render 'meta '([x "1"]) '()) "")
(check-equal? (render 'unsubscribe '() '("u")) "")

;; Attribute binding, #:when guards and optional attributes
(check-equal? (render 'photo '([source "cat"] [ext "avif"] [id "c"]) '())
              '(img ([src "/cat-1000.avif"] [id "c"])))
(check-equal? (render 'photo '([source "cat"] [ext "avif"]) '())
              '(img ([src "/cat-1000.avif"])))
(check-equal? (render 'photo '([source "cat"] [ext "webp"]) '())
              '(img ([src "/cat.webp"])))
(check-equal? (render 'note-card '([id "n1"] [title "T"] [block "root"]) '("body"))
              '(section ([id "n1"]) (h3 "T") "body"))

;; A missing required attribute skips the clause, so the element falls through to the default
(check-equal? (render 'note-card '([id "n1"]) '("body"))
              '(note-card ([id "n1"]) "body"))

;; Bodies can hold definitions
(check-equal? (render 'poetry '() '("a" "b"))
              '(div ([class "poem"] [data-lines "2"]) "a" "b"))

;; Unknown tags go to default-html-tag
(check-equal? (render 'kbd '() '("Enter")) '(kbd "Enter"))
(check-equal? (render 'abbr '([title "x"]) '("y")) '(abbr ([title "x"]) "y"))

;; An else clause replaces the default
(define strip
  (html-rules (tag attrs elems)
    [keep #:as span.kept]
    [else `(span ,@elems)]))
(check-equal? (strip 'keep '() '("a")) '(span ([class "kept"]) "a"))
(check-equal? (strip 'other '([x "1"]) '("a")) '(span "a"))

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Typst

(define-typst-rules (render/typst tag attrs elems)
  [(or meta unsubscribe) ""]
  [margin-note #:as aside]
  [note #:as callout.info]
  [(abbreviation term)
   (format "#abbr(\"~a\")[~a]" (escape-typst-string term) (string-append* elems))])

(check-equal? (render/typst 'margin-note '([block "root"]) '("a")) "#aside[a]")
(check-equal? (render/typst 'note '() '("a")) "#callout(class: \"info\")[a]")
(check-equal? (render/typst 'meta '() '()) "")
(check-equal? (render/typst 'abbreviation '([term "Say \"hi\""]) '("SH"))
              "#abbr(\"Say \\\"hi\\\"\")[SH]")
(check-equal? (render/typst 'side-bar '([x "1"]) '("a")) "#side_bar(x: \"1\")[a]")

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Generic, with any default

(define default-calls 0)
(define-rules (render/plain tag attrs elems)
  #:default (begin (set! default-calls (add1 default-calls))
                   (make-plaintext-fallback 72))
  [(or meta unsubscribe) ""]
  [aside #:as note])

(check-equal? (render/plain 'meta '() '("x")) "")
(check-equal? (render/plain 'aside '() '("a")) "[note] a\n\n")
(check-equal? (render/plain 'other '() '("a")) "[other] a\n\n")
(check-equal? default-calls 1 "#:default is evaluated once")

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Syntax errors

(define (expand-error-message datum)
  (with-handlers ([exn:fail:syntax? exn-message])
    (parameterize ([current-namespace (make-base-namespace)])
      (namespace-require 'punct/render/html)
      (namespace-require 'punct/render/base)
      (expand datum))
    #f))
(check-regexp-match #rx"class names"
                    (expand-error-message '(html-rules (t a e) [x #:as div..y])))
(check-regexp-match #rx"class names"
                    (expand-error-message '(html-rules (t a e) [x #:as .y])))
(check-not-false (expand-error-message '(html-rules (t a e) [x #:as])))
(check-not-false (expand-error-message '(html-rules (t a e) [else 1] [x 2])))
(check-not-false (expand-error-message '(rules (t a e) [x 1]))
                 "rules needs #:default")

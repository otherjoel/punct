#lang racket/base

(require punct/doc
         punct/element
         punct/fetch
         punct/parse
         racket/match
         racket/runtime-path
         rackunit)

(define-runtime-path test-metas "test-metas.page.rkt")
(define-runtime-path test-md-basic "test-md-basic.page.rkt")
(define-runtime-path test-metas-multibyte "test-metas-multibyte.page.rkt")

(define (get-doc/unhere p)
  (match (get-doc p)
    [(document meta body fns)
     (document (hash-set meta 'here-path ".") body fns)]))

(module+ test
  (check-equal?
   (get-doc/unhere test-metas)
   (document
    '#hasheq((boxed . #:17)
             (case-insensitive-symbol-with-space . |hob nob|)
             (commented-number . 14)
             (draft? . #t)
             (fav-number . 2+3i)
             (fruit-ratings . #hash((apple . 4) (grape . 3) (pear . 5)))
             (here-path . ".")
             (name-regex . #rx"(Bob|Alice)")
             (nemesis-struct . #s(prefab:clown "Binky" "pie"))
             (non-cyclic-graph . (42 42 42))
             (|now you're just showing off| . (module anonymous-module scribble/manual/lang (#%module-begin doc " There are " (+ 3 4) " words in this anonymous module")))
             (|other- numbers| . (7 5 2/3))
             (title . "This is a normal string value")
             (vector . #(23 22 9811)))
    '((paragraph "hello"))
    '())
   "Exotic quoted datums in meta values read properly")
  
  (check-equal?
   (get-doc/unhere test-md-basic)
   (document
    '#hasheq((here-path . "."))
    '((heading ((level "1")) "h1 Heading 8-)")
      (heading ((level "2")) "h2 Heading")
      (heading ((level "3")) "h3 Heading")
      (heading ((level "4")) "h4 Heading")
      (heading ((level "5")) "h5 Heading")
      (heading ((level "6")) "h6 Heading")
      (paragraph "Alternatively, for H1 and H2, an underline-ish style:")
      (heading ((level "1")) "Alt-H1")
      (heading ((level "2")) "Alt-H2")
      (paragraph "Emphasis, aka italics, with " (italic "asterisks") " or " (italic "underscores") ".")
      (paragraph "Strong emphasis, aka bold, with " (bold "asterisks") " or " (bold "underscores") ".")
      (paragraph "Combined emphasis with " (bold "asterisks and " (italic "underscores")) ".")
      (paragraph "Strikethrough using tildes is NOT supported: ~~Scratch this.~~")
      (paragraph (bold "This is bold text"))
      (paragraph (bold "This is bold text"))
      (paragraph (italic "This is italic text"))
      (paragraph (italic "This is italic text")))
    '())
   "Markdown: basic headings and inline formatting parse as expected")

  ;; Issue #9
  (check-equal?
   (get-doc/unhere test-metas-multibyte)
   (document '#hasheq((fuzz . "🧜🏽‍♀️🙅🏽‍♂️👨🏼‍❤️‍💋‍👨🏾")
                      (here-path . ".")
                      (title . "ěščřžýáíé"))
             '((paragraph "ěščřžýáíé") (paragraph "🧜🏽‍♀️🙅🏽‍♂️👨🏼‍❤️‍💋‍👨🏾"))
             '())
   "Multibyte UTF-8 encodings preserved in meta values and body")

  ;; Blank lines inside element content should not crash the parser
  (check-not-exn
   (λ ()
     (parse-markup-elements
      '#hasheq()
      '("Hello" "\n" "\n" (foo-bar "one two three" "\n" "\n" " four five six"))))
   "Blank line inside element content does not crash")

  ;; define-element / default-element-function tests
  (let ()
    (define-element kbd #:class "key")

    (check-equal?
     (kbd "CTRL")
     '(kbd ((class "key")) "CTRL")
     "define-element: default keyword attr is applied")

    (check-equal?
     (kbd "CTRL" #:class "special")
     '(kbd ((class "special")) "CTRL")
     "define-element: call-site keyword overrides default (no duplicates)")

    (check-equal?
     (kbd "CTRL" #:id "main")
     '(kbd ((class "key") (id "main")) "CTRL")
     "define-element: non-overlapping call-site keyword is merged with default"))

  (let ()
    (define el (default-element-function 'span #:class "default" #:id "x"))

    (check-equal?
     (el "hi" #:class "override")
     '(span ((id "x") (class "override")) "hi")
     "default-element-function: duplicate keyword uses call-site value")

    (check-equal?
     (el "hi" #:class "override" #:id "y")
     '(span ((class "override") (id "y")) "hi")
     "default-element-function: both defaults overridden"))

  (let ()
    (define el (default-element-function 'div))

    (check-equal?
     (el "hi")
     '(div "hi")
     "default-element-function: no attrs when none provided")

    (check-equal?
     (el "hi" #:class "c")
     '(div ((class "c")) "hi")
     "default-element-function: call-site attrs work with no defaults"))
  )


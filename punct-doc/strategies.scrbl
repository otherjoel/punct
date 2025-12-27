#lang scribble/manual

@(require [for-label punct/core
                     punct/doc
                     punct/fetch
                     punct/render/base
                     punct/render/html
                     punct/render/typst
                     racket/base
                     racket/class
                     racket/format
                     racket/match
                     racket/string
                     racket/system
                     (only-in xml xexpr? xexpr->string)])

@(require scribble/examples "tools.rkt")
@(define ev (sandbox))
@(ev '(require punct/doc punct/parse punct/element punct/render/html punct/render/typst))

@title{Rendering Strategies}

A Punct document is format-independent; its AST can be converted to any output format you need.
Punct provides built-in renderers for HTML, @|Typst|, and plain text.

This section explains how to use these renderers effectively, how to handle custom elements
in your output, and when you might want to extend the base renderer for your own needs.

@section{Rendering to HTML}

HTML is the most common output format for web publishing. To render a Punct document to HTML,
use @racket[doc->html] or @racket[doc->html-xexpr]:

@codeblock|{
#lang racket

(require punct/fetch
         punct/render/html)

;; Render a document to an HTML string
(define html-output (doc->html (get-doc "my-article.rkt")))

;; Or get the intermediate X-expression for further processing
(define html-xexpr (doc->html-xexpr (get-doc "my-article.rkt")))
}|

The HTML renderer wraps the document body in an @tt{<article>} element. Footnotes, if present,
are collected into a @tt{<section class="footnotes">} at the end.

@subsection{A complete HTML rendering example}

Here's a simplistic example that renders a Punct document to a standalone HTML file:

@codeblock|{
#lang racket

(require punct/fetch
         punct/render/html
         xml)

(define (render-page source-path output-path title)
  (define doc (get-doc source-path))
  (define body-html (doc->html doc))

  (define full-html
    (string-append
      "<!DOCTYPE html>\n"
      "<html lang=\"en\">\n"
      "<head>\n"
      "  <meta charset=\"utf-8\">\n"
      "  <title>" title "</title>\n"
      "  <link rel=\"stylesheet\" href=\"style.css\">\n"
      "</head>\n"
      "<body>\n"
      body-html
      "\n</body>\n"
      "</html>"))

  (call-with-output-file output-path
    (lambda (out) (display full-html out))
    #:exists 'replace))

;; Usage:
;; (render-page "my-article.rkt" "my-article.html" "My Article")
}|

@subsection{Handling custom elements in HTML}

When your Punct document contains @tech{custom elements}, you need to tell the HTML renderer how to
convert them. Provide a @tech{fallback function} as the second argument to @racket[doc->html]:

@codeblock|{
#lang racket

(require punct/fetch
         punct/render/html
         racket/match)

;; Define how to render custom elements
(define (my-html-fallback tag attrs elems)
  (match (list tag attrs)
    ;; Convert 'abbreviation to HTML <abbr>
    [`(abbreviation [[term ,term]])
     `(abbr [[title ,term]] ,@elems)]

    ;; Convert 'note to a styled div
    [`(note ,_)
     `(div [[class "note"]] ,@elems)]

    ;; Convert 'youtube to an iframe
    [`(youtube [[id ,video-id]])
     `(iframe [[src ,(string-append "https://www.youtube.com/embed/" video-id)]
               [width "560"]
               [height "315"]
               [frameborder "0"]
               [allowfullscreen ""]])]

    ;; Fall through to default behavior for anything else
    [_ (default-html-tag tag attrs elems)]))

(define (render-with-custom-elements source-path)
  (doc->html (get-doc source-path) my-html-fallback))
}|

@section{Rendering to Typst}

@Typst is a modern typesetting system for producing PDF documents. Punct includes a Typst renderer
which converts your document to Typst markup, which you can then compile with the @tt{typst}
command-line tool.

@codeblock|{
#lang racket

(require punct/fetch
         punct/render/typst)

(define typst-output (doc->typst (get-doc "my-article.rkt")))
}|

@subsection{A complete Typst rendering example}

Here's a complete workflow for rendering Punct documents to PDF via Typst:

@codeblock|{
#lang racket

(require punct/fetch
         punct/render/typst
         racket/system)

(define (render-to-pdf source-path output-pdf)
  (define doc (get-doc source-path))
  (define typst-path (path-replace-extension output-pdf ".typ"))

  ;; Add Typst preamble for document setup
  (define typst-content
    (string-append
      "#set page(paper: \"us-letter\", margin: 1in)\n"
      "#set text(font: \"Linux Libertine\", size: 11pt)\n"
      "#set par(justify: true)\n\n"
      (doc->typst doc)))

  ;; Write the .typ file
  (call-with-output-file typst-path
    (lambda (out) (display typst-content out))
    #:exists 'replace)

  ;; Compile to PDF using Typst CLI
  (system* (find-executable-path "typst")
           "compile" typst-path output-pdf))

;; Usage:
;; (render-to-pdf "my-article.rkt" "my-article.pdf")
}|

@subsection{Handling custom elements in Typst}

Just as with HTML, you can provide a @tech{fallback function} for custom elements:

@codeblock|{
#lang racket

(require punct/fetch
         punct/render/typst
         racket/match)

(define (my-typst-fallback tag attrs elems)
  (match (list tag attrs)
    ;; Render 'note as a Typst callout box
    [`(note ,_)
     (string-append "#block(fill: luma(230), inset: 1em, radius: 4pt)[\n"
                    (string-join elems)
                    "\n]")]

    ;; Render 'abbreviation with a tooltip (using Typst's tooltip package)
    [`(abbreviation [[term ,term]])
     (string-append "#underline[" (string-join elems) "]")]

    ;; Fall through to default
    [_ (default-typst-tag tag attrs elems)]))

(define (render-typst-with-custom source-path)
  (doc->typst (get-doc source-path) my-typst-fallback))
}|

Note that in Typst fallbacks, the @racket[elems] have already been escaped and rendered to strings,
so you typically join them with @racket[string-join] or @racket[string-append].

@subsection{Using the default Typst fallback}

The default @tech{fallback function} (@racket[default-typst-tag]) converts custom elements directly
to Typst function calls. For example, a custom element like @racket['(note "Important!")] becomes
@tt{#note[Important!]} in the output. Attributes become named arguments: @racket['(note [[class "info"]] "Text")]
becomes @tt{#note(class: "info")[Text]}.

This means you can define corresponding functions in your Typst template, and your custom elements
will automatically call them:

@codeblock|{
#lang racket

(require punct/fetch
         punct/render/typst
         racket/system)

(define (render-to-pdf source-path output-pdf)
  (define doc (get-doc source-path))
  (define typst-path (path-replace-extension output-pdf ".typ"))

  ;; Typst preamble with custom function definitions
  (define typst-preamble #<<PREAMBLE
#set page(paper: "us-letter", margin: 1in)
#set text(font: "Linux Libertine", size: 11pt)

// Define a function that matches your custom Punct element.
// Named arguments come from element attributes; content from elements.
#let note(type: "info", body) = {
  let fills = (info: luma(230), warning: rgb("#fff3cd"))
  block(
    fill: fills.at(type),
    inset: 1em,
    radius: 4pt,
    body
  )
}

PREAMBLE
)

  (define typst-content
    (string-append typst-preamble "\n" (doc->typst doc)))

  (call-with-output-file typst-path
    (lambda (out) (display typst-content out))
    #:exists 'replace)

  (system* (find-executable-path "typst")
           "compile" typst-path output-pdf))
}|

With this setup, a Punct source like:

@codeblock|{
#lang punct

•(define-element note)

•note{Remember to save}

•note[#:type "warning"]{This action cannot be undone.}
}|

...will render as @tt{#note[Remember to save]} and @tt{#note(type: "warning")[This action cannot be undone.]},
calling the @tt{note} function defined in the Typst preamble with the appropriate arguments.

@section[#:tag "extending-renderer"]{Extending the Renderer}

Sometimes providing a @tech{fallback function} isn't enough. You might need to:

@itemlist[#:style 'compact
@item{Change how standard elements (like headings or links) are rendered}
@item{Add wrapper content around the rendered body}
@item{Maintain state across the rendering process}
@item{Target a format not covered by the built-in renderers (e.g., LaTeX, Markdown, or a custom XML format)}
]

In these cases, you can extend @racket[punct-abstract-render%], the base class that all Punct
renderers inherit from.

@subsection{Extending an existing renderer}

The simplest approach is to extend one of the built-in renderers. Here's an example that customizes
the HTML renderer to add automatic IDs to headings:

@codeblock|{
#lang racket

(require punct/render/html
         punct/doc
         racket/class
         racket/string)

(define punct-html-with-ids%
  (class punct-html-render%
    (super-new)

    ;; Override heading rendering to add an id attribute
    (define/override (render-heading level elems)
      (define tag (string->symbol (format "h~a" level)))
      (define text (string-join (map ~a elems)))
      (define id (string-downcase
                   (regexp-replace* #rx"[^a-zA-Z0-9]+" text "-")))
      `(,tag [[id ,id]] ,@elems))))

(define (doc->html-with-ids doc [fallback default-html-tag])
  (send (new punct-html-with-ids% [doc doc] [render-fallback fallback])
        render-document))
}|

When extending an existing renderer, you need only override the methods whose behavior you want to
change.

@subsection{Creating a custom renderer from scratch}

For a new output format, extend @racket[punct-abstract-render%] directly and implement all the
abstract methods. Here's a minimal example that renders to a simple Markdown-like format:

@codeblock|{
#lang racket

(require punct/render/base
         punct/doc
         racket/class
         racket/string)

(define punct-simple-markdown%
  (class punct-abstract-render%
    (super-new)

    ;; Helper to join rendered elements
    (define (join elems) (string-append* (map ~a elems)))

    ;; Block elements
    (define/override (render-heading level elems)
      (string-append (make-string (string->number level) #\#)
                     " " (join elems) "\n\n"))

    (define/override (render-paragraph elems)
      (string-append (join elems) "\n\n"))

    (define/override (render-thematic-break)
      "---\n\n")

    (define/override (render-code-block info elems)
      (string-append "```" info "\n" (join elems) "\n```\n\n"))

    (define/override (render-blockquote elems)
      (define lines (string-split (join elems) "\n"))
      (string-append
        (string-join (map (lambda (l) (string-append "> " l)) lines) "\n")
        "\n\n"))

    (define/override (render-itemization style start elems)
      (define marker (if (non-empty-string? start) "1. " "- "))
      (string-append
        (string-join
          (for/list ([e (in-list elems)])
            (string-append marker e))
          "\n")
        "\n\n"))

    (define/override (render-item elems)
      (string-trim (join elems)))

    (define/override (render-html-block elem) elem)

    ;; Inline elements
    (define/override (render-bold elems)
      (string-append "**" (join elems) "**"))

    (define/override (render-italic elems)
      (string-append "_" (join elems) "_"))

    (define/override (render-code elems)
      (string-append "`" (join elems) "`"))

    (define/override (render-link dest title elems)
      (string-append "[" (join elems) "](" dest ")"))

    (define/override (render-image src title desc elems)
      (string-append "![" desc "](" src ")"))

    (define/override (render-line-break) "\n")

    (define/override (render-html elem) elem)

    (define/override (render-footnote-reference label defnum refnum)
      (string-append "[^" label "]"))

    (define/override (render-footnote-definition label refcount elems)
      (string-append "[^" label "]: " (join elems) "\n"))

    ;; Override render-document to return a single string
    (define/override (render-document)
      (define-values [body footnotes] (super render-document))
      (string-append (string-append* body)
                     (if (null? footnotes) "" "\n")
                     (string-append* footnotes)))))

(define (doc->simple-markdown doc [fallback (lambda (t a e) (string-append* e))])
  (send (new punct-simple-markdown% [doc doc] [render-fallback fallback])
        render-document))
}|

See the @secref["rendering-api"] section in the Module Reference for complete documentation of
@racket[punct-abstract-render%] and the methods you need to implement.

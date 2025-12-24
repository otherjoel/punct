#lang scribble/manual

@(require (for-label punct/doc
                     punct/render/html))

@(require scribble/examples "tools.rkt")
@(define ev (sandbox))
@(ev '(require punct/doc punct/parse punct/element))

@title{Quick start}

Open DrRacket and start a new file like so:

@filebox["Untitled 1"]{@codeblock{
  #lang punct

  ---
  author: Me
  ---

  # My first Punct doc

  Simple.
}}

As you can see, this document uses
@hyperlink["https://www.markdownguide.org/basic-syntax/"]{Markdown} formatting and has a little
metadata block near the beginning. It's essentially a normal Markdown file, very much like one you
would use with most publishing systems. The only thing that makes it different is the addition of
@racketmodfont{#lang punct} at the top.

Now click the @onscreen{Run} button in the toolbar. Punct will parse the document's Markdown content
and metadata, and produce a @racket[document] struct containing the metadata and an Abstract Syntax
Tree (AST):

@racketblock[
 (document '#hasheq((author . "Me") (here-path . "7-unsaved-editor"))
           '((heading ((level "1")) "My first Punct doc") (paragraph "Simple."))
           '())]

This value is automatically bound to @racketid[doc]. The metadata at the top is included in that
value, but is also bound to @racketid[metas].

@(ev '(define doc
        (document '#hasheq((author . "Me") (here-path . "7-unsaved-editor"))
'((heading ((level "1")) "My first Punct doc") (paragraph "Simple."))
'())))

@(ev '(define metas '#hasheq((author . "Me") (here-path . "7-unsaved-editor"))))

@examples[#:eval ev
          #:label #f
          doc
          metas]

Both of these bindings are also @racket[provide]d so you can access them from other modules with
@racket[require] or @racket[dynamic-require].

You can render @racketid{doc} to HTML by passing it to @racket[doc->html]. In the REPL:

@examples[#:eval ev
          #:label #f
          (require punct/render/html)
          (doc->html doc)]

You can escape to Racket code using the @litchar{•} "bullet" character (@tt{U+2022}):

@codeblock{
 #lang punct

 Today we're computing •(+ 1 2).

 •string-upcase{keep it down, buddy.}
}

@margin-note{Punct does not care what extension you use for your filenames. Using @filepath{.rkt} is
the simplest thing to do if you are using DrRacket, but you can use whatever you want. I use
@filepath{.page.rkt} in my projects.}

Any simple values produced by Racket code are converted to strings at compile time. If these strings
contain valid Markdown, they will be parsed along with the rest of the document. The code below will
produce a bulleted list:

@codeblock{
 #lang punct

 Three things to remember:

 •(apply string-append
         (map (λ (s) (format "* ~a\n" (string-upcase s)))
              '("keep" "it" "down")))
}

Results in:

@racketblock[
 (document '#hasheq((here-path . "7-unsaved-editor"))
           '((paragraph "Three things to remember:")
             (itemization ((style "tight") (start "#f"))
                          (item "KEEP")
                          (item "IT")
                          (item "DOWN")))
           '())]

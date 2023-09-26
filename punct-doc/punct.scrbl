#lang scribble/manual

@(require [for-label commonmark
                     punct/core
                     punct/doc
                     punct/fetch
                     punct/parse
                     punct/render/html
                     punct/render/plaintext
                     racket/base
                     racket/contract/base
                     racket/match
                     (only-in xml xexpr?)])
@(require scribble/examples "tools.rkt")
@(define ev (sandbox))

@(ev '(require punct/doc punct/parse))

@title[#:style '(toc)]{Punct: CommonMark + Racket}
@author[(author+email "Joel Dueck" "joel@jdueck.net")]

@defmodulelang[punct]

Punct is a programming environment for publishing things, implemented in Racket. Punct’s two basic
ideas are:

@itemlist[#:style 'ordered

@item{Markdown documents (parsed by @racketmodname[commonmark]), extensible with Racket code.}

@item{Multiple output formats. A Punct program/document produces a format-independent AST.}]

The latest version of this documentation can be found at
@link["https://joeldueck.com/what-about/punct/"]{@tt{joeldueck.com}}. The source and installation
instructions are at the project’s @link["https://github.com/otherjoel/punct"]{GitHub repo}.

@youtube-embed-element["https://www.youtube.com/embed/9zxna1tlvHU"]

I have designed Punct for my own use and creative needs. If you would like Punct to work differently
or support some new feature, I encourage you to fork it and customize it yourself.

This documentation assumes you are familiar with Racket, and with @racketlink[xexpr?]{X-expressions}
and associated terms (attributes, elements, etc).

@local-table-of-contents[]

@section{Quick start}

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
metadata block near the beginning. It’s essentially a normal Markdown file, very much like one you
would use with most publishing systems. The only thing that makes it different is the addition of
@racketmodfont{#lang punct} at the top.

Now click the @onscreen{Run} button in the toolbar. Punct will parse the document’s Markdown content
and metadata, and produce a @racket[document] struct containing the metadata and an Abstract Syntax
Tree (AST):

@racketblock[
 '#s(document #hasheq((author . "Me") (here-path . "7-unsaved-editor"))
              ((heading ((level "1")) "My first Punct doc") (paragraph "Simple."))
              ())]

This value is automatically bound to @racketid[doc]. The metadata at the top is included in that
value, but is also bound to @racketid[metas].

@(ev '(define doc
        '#s(document #hasheq((author . "Me") (here-path . "7-unsaved-editor"))
((heading ((level "1")) "My first Punct doc") (paragraph "Simple."))
())))

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

You can escape to Racket code using the @litchar{•} “bullet” character (@tt{U+2022}):

@codeblock{
 #lang punct

 Today we’re computing •(+ 1 2).

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
 '#s(document #hasheq((here-path . "7-unsaved-editor"))
              ((paragraph "Three things to remember:")
                 (itemization ((style "tight") (start "#f"))
                              (item "KEEP")
                              (item "IT")
                              (item "DOWN")))
              ())]

@section{Custom elements}

You can use Racket code to introduce new elements to the document’s structure.

A @deftech{custom element} is an @racket[xexpr?] that begins with a symbol other than those produced
by the Markdown parser. A custom element may optionally have a set of @deftech{attributes}, which is
a list of key/value pairs that appears as the second item in the list. The keys must be symbols and
the values must be strings, or an exception is raised.

Here is an example of a function that produces a custom @tt{abbreviation} element with a @tt{term}
attribute:

@codeblock|{
#lang punct

•(define (a term . elems)
   `(abbrevation [[term ,term]] ,@elems))

Writing documentation in Javascript? •a["Laugh out loud"]{LOL}.
}|

Produces:

@racketblock[
'#s(document #hasheq((here-path . "7-unsaved-editor"))
             ((paragraph
               "Writing documentation in Javascript? "
               (abbrevation ((term "Laugh out loud")) "LOL")
               "."))
             ())
]

@subsection{Inline and Block Content}

Any @tech{custom elements} you introduce need to play nicely with CommonMark’s @secref["structure"
#:doc '(lib "scribblings/commonmark.scrbl")], in particular its distinction between @secref["blocks"
#:doc '(lib "scribblings/commonmark.scrbl")] and @secref["inlines" #:doc '(lib
"scribblings/commonmark.scrbl")].

@itemlist[

@item{Inline content must be contained in a block and can only contain other inline content. If
found on a line by itself, inline content will be automatically wrapped in a @tt{paragraph} block
element. Italics and links are examples of inline content.}

@item{Blocks can contain other blocks as well as inline content, and will not be auto-wrapped in
@tt{paragraph} elements. Paragraphs and headings are examples of block content.}]

By default, Punct will treat custom elements as inline content.

If you want a custom element to count as a block (that is, to avoid having it auto-wrapped inside
a @tt{paragraph} element), you must give it a @racket['block] attribute with a value of either
@racket["root"] or @racket["single"]:

@itemlist[

@item{@racket["root"] should be used for blocks that might contain other block elements.
@bold{Limitations:} @racket["root"]-type blocks cannot be contained inside Markdown-created
@tech[#:doc '(lib "scribblings/commonmark.scrbl")]{flows} (such as block quotations notated using
@litchar{>}); if found inside such a flow, they will “escape” out to the root level of the
document.}

@item{@racket["single"] should be used for block elements that might need to be contained within
Markdown-created @tech[ #:doc '(lib "scribblings/commonmark.scrbl")]{flows}. @bold{Limitations:}
@racket["single"]-type blocks must appear on their own line or lines in order to be counted as
blocks.}]

If that seems complicated, think of it this way: there are three kinds of flows that you can notate
with Markdown: block quotes, list items, and footnote definitions. If your custom block element
might appear as a direct child of any of those three Markdown notations, you should probably start
by giving it the @racket['(block "single")] attribute.

You’ll never get an error for using the wrong @racket['block] type on your custom elements; you’ll
just get unexpected results in the structure of your document.

@bold{Under the hood:} The two types of blocks above correspond to two methods Punct uses to trick
the CommonMark parser into treating custom elements as blocks. With @racket["root"]-type blocks,
Punct inserts extra line breaks (which is what causes these blocks to “escape” out of Markdown
blockquotes to the document’s root level, just as it would if you typed two linebreaks in your
source). With @racket["single"]-type blocks, Punct allows CommonMark to wrap the element in
a @tt{paragraph}, then looks for any paragraph that contains @emph{only} a @racket["single"]-type
block and “shucks” them out of their containing paragraphs. The need for such tricks comes from
a design decision to use the @racketmodname[commonmark] package exactly as published, without
forking or customizing it in any way.

@subsection[#:tag "rendering-custom-elements"]{Rendering custom elements}

When rendering your document to a specific output format (such as HTML) you’ll want to provide
a fallback procedure to the renderer that can convert those elements into that specific format.

Your fallback function will be given three arguments: the tag, a list of attributes, and a list of
sub-elements found inside your element. The elements will already have been fully processed by
Punct.

Here’s an example pair of functions for rendering documents containing the custom @tt{abbreviation}
element (from the examples above) into HTML:

@racketblock[

(define (custom-html tag attrs elems)
  (match `(,tag ,attrs)
    [`(abbreviation [[term ,term]]) `(abbr [[title ,term]] ,@elems)]))

(define (my-html-renderer source-path)
  (doc->html (get-doc source-path) custom-html))

]

@section{Writing Punct}

Start your Punct source file with @racketmodfont{#lang punct}. Then just write in
CommonMark-flavored Markdown.

Punct allows inline Racket code that follows @secref["reader" #:doc '(lib
"scribblings/scribble/scribble.scrbl")] but with the @litchar{•} “bullet” character (@tt{U+2022}) as
the control character instead of @litchar{@"@"}.  On Mac OS, you can type this using @tt{ALT+8}.

Punct source files automaticaly @racket[provide] two bindings: @racketidfont{doc} (a
@racket[document]) and @racketidfont{metas} (a hash table).

@subsection{Using @racket[require]}

By default, Punct programs have access to the bindings in @racketmodname[racket/base] and
@racketmodname[punct/core]. You can import bindings from other modules in two ways:

@itemlist[#:style 'ordered

@item{By using @racket[require] as you usually would, or}

@item{By adding one or more @secref["module-paths" #:doc '(lib "scribblings/guide/guide.scrbl")]
directly on the @hash-lang[] line.}]

@codeblock{
 #lang punct "my-module.rkt" racket/math

 •; All bindings in "my-module.rkt" and racket/math are now available
 •; You can also just use require normally
 •(require racket/string)
}

@subsection{Metadata block}

Sources can optionally add metadata using key: value lines delimited by lines consisting only of
consecutive hyphens:

@codeblock{
 #lang punct
 ---
 title: Prepare to be amazed
 date: 2020-05-07
 ---

 Regular content goes here
}

This is a syntactic convenience that comes with a few rules and limitations:

@itemlist[#:style 'compact

@item{The metadata block must be the first non-whitespace thing that follows the
@racketmodfont{#lang} line.}

@item{The values will always be parsed as flat strings.}

@item{The reader will not evaluate any escaped code inside the metadata block; all characters in the
keys and values will be used verbatim.}]

If you want to use non-string values, or the results of expressions, in your metadata, you can use
the @racket[set-meta] function anywhere in the document or in code contained in other modules.
Within the document body you can also use the @racket[?] macro as shorthand for @racket[set-meta].

@section{Rendering}

A Punct document is format-independent; when you want to use it in an output file, it must be
rendered into that output file’s format.

Punct includes an HTML renderer and a plain-text renderer, and is designed to include renderers for
more formats in the future.

@subsection{Rendering HTML}

@defmodule[punct/render/html]

@defproc[(doc->html [pdoc document?] [fallback (-> symbol? list? list? xexpr?) default-html-tag]) string?]{

Renders @racket[_pdoc] into a string containing HTML markup. Each @tech{custom element} is passed to
@racket[_fallback], which must return an @racketlink[xexpr?]{X-expression}.

For more information on using the @racket[_fallback] argument to render custom elements, see
@secref["rendering-custom-elements"].

}

@defproc[(doc->html-xexpr [pdoc document?] [fallback (-> symbol? list? list? xexpr?) default-html-tag]) xexpr?]{

Renders @racket[_pdoc] into HTML, but in @racketlink[xexpr?]{X-expression} form rather than as a
string. Each @tech{custom element} is passed to @racket[_fallback], which must itself return an
X-expression.

For more information on using the @racket[_fallback] argument to render custom elements, see
@secref["rendering-custom-elements"].

}

@defproc[(default-html-tag [tag symbol?] [attributes (listof (listof symbol? string?))] [elements list?]) xexpr?]{

Returns an X-expression comprised of @racket[_tag], @racket[_attributes] and @racket[_elements].
Mainly used as the default fallback procedure for @racket[doc->html].

@examples[#:eval ev
(default-html-tag 'kbd '() '("Enter"))
(default-html-tag 'a '((href "http://example.com")) '("Link"))
]
}

@subsection{Rendering plain text}

@defmodule[punct/render/plaintext]

Sometimes you want to convert a document into a text format that is even plainer than Markdown, such
as when generating the plaintext version of an email newsletter.

@defproc[(doc->plaintext [pdoc document?]
                         [line-width exact-nonnegative-integer?]
                         [fallback (symbol? (listof (listof symbol? string?)) list? . -> . string?)
                                   (make-plaintext-fallback line-width)]) string?]{

Renders @racket[_pdoc] into a string of plain text, hard-wrapped to @racket[_line-width] characters
(except for block-quotes, which are hard-wrapped to a length approximately 75% as long as
@racket[_line-width]). Any @tech{custom elements} are passed to @racket[_fallback], which must
return a string.

The function applies very rudimentary text formatting which usually looks as you would expect, but
which often discards information.

@itemlist[

@item{Level 1 headings are underlined with @litchar{=}, and all other headings are underlined with
@litchar{-}.}

@item{Link destination URLs are given inside parentheses directly following the link text.}

@item{Code blocks are indented with four spaces, and the language name, if any, is discarded.}

@item{Images are replaced with their “alt” text, prefixed by @racket["Image: "] and wrapped in
parentheses; the source URL and title are discarded.}

]

For more information on using the @racket[_fallback] argument to render custom elements, see
@secref["rendering-custom-elements"].

@examples[#:eval ev
          (require punct/render/plaintext)
          (define email (parse-markup-elements (hasheq) '("# Issue No. 1\n\nHowdy!")))
          (display (doc->plaintext email 72))]

}


@defproc[(make-plaintext-fallback [width exact-nonnegative-integer?])
         (symbol? (listof (listof symbol? string?)) list? . -> . string?)]{

Returns a function that accepts three arguments (the tag, attributes and elements of an
X-expression).  Mainly used to create the default fallback procedure for @racket[doc->plaintext].

@examples[#:eval ev
(define foo (make-plaintext-fallback 72))
(foo 'kbd '() '("Enter"))
(foo 'a '((href "http://example.com")) '("Link"))
]
}

@section{Module Reference}

@subsection{Core}

@defmodule[punct/core]

@defparam[current-metas metas (or/c hash-eq? #f)]{

A parameter that, during compilation of a Punct source, holds the metadata hash table for that file.
The final value of this parameter becomes the value of @racket[document-metas] for that file’s
@racketidfont{doc} as well as its @racketidfont{metas} export.

The only key automatically defined in every metadata table is @racket['here-path], which holds the
absolute path to the source file.

If no Punct file is currently being compiled, this parameter will hold @racket[#f] by default. In
particular, this parameter is @emph{not} automatically set to a Punct file’s @racketidfont{metas}
during the rendering phase (e.g., @racket[doc->html]).

}

@defproc[(set-meta [key symbol?] [val (not/c procedure?)]) void?]{

Set the value of @racket[_key] in @racket[current-metas] to @racket[_val]. If there are no current
metas, an ugly exception is thrown.

}

@defform[(? key val-expr ...)]{

Within a Punct file, this macro can be used as shorthand for @racket[set-meta]. Each @racket[_key]
is given as a bare identifier (i.e., without using @racket[quote]).

@codeblock{
#lang punct

•?[title "Example Title" author "Me"]

...}

}

@subsection{Doc}

@defmodule[punct/doc]

The bindings provided by this module are also provided by @racketmodname[punct/core].

@defstruct[document ([metas hash-eq?] [body (listof xexpr?)] [footnotes (listof xexpr?)]) #:prefab]{

A parsed Punct document.

@history[#:changed "1.0" @elem{@racket[_body] and @racket[_footnotes] now guaranteed to be valid
X-expressions and not simply lists.}]

}

@subsection{Fetch}

@defmodule[punct/fetch]

@defproc[(get-doc [src path-string?]) document?]{

Returns the @racketidfont{doc} binding from @racket[_src]. No caching is used; this function is
basically a thin wrapper around @racket[dynamic-require]. If @racket[_src] does not exist, you will
get a friendly error message. If any other kind of problem arises, you will get an ugly error.

}

@defproc[(get-doc-ref [src path-string?] [key symbol?]) any/c]{

Returns the value of @racket[_key] in the @racketidfont{metas} hash table provided by @racket[_src],
or @racket[#f] if the key does not exist in that hash table. If @racket[_src] does not exist, you
will get a friendly error message. If any other kind of problem arises, you will get an ugly error.

}

@subsection{Parse}

@defmodule[punct/parse]

@defproc[(parse-markup-elements [metas hash-eq?]
                                [elements list?]
                                [#:extract-inline? extract? #t]
                                [#:parse-footnotes? parse-fn? #f])
         (or/c document? list?)]{

Parses @racket[_elements] into a Punct AST by serializing everything as a string, sending the string
through the @racketmodname[commonmark] parser, and then converting the result into a Punct
@racket[document], reconstituting any @tech{custom elements} in the process.

If @racket[#:extract-inline?] is @racket[#true], and if the parsed document contains only a single
@tt{paragraph} element at the root level, then the inline content of the paragraph is returned as
a list. Otherwise, the entire result is returned as a @racket[document].

The @racket[#:parse-footnotes?] argument determines whether the @racketmodname[commonmark] parser
will parse Markdown-style footnote references and definitions in @racket[_elements].

@examples[#:eval ev

(define elems
  '("# Title\n\nA paragraph with *italic* text, and "
    1
    (custom "custom element")))
(parse-markup-elements (hasheq) elems)]

}

@section{Differences from Pollen}

Punct is heavily indebted to @seclink["top" #:indirect? #t #:doc '(lib "pollen/scribblings/pollen.scrbl")]{Pollen}.
Much of its design and code comes from Pollen. And because Punct sources provide bindings for
@racketidfont{doc} and @racketidfont{metas} just like Pollen markup sources do, you should be
able to use Punct sources in Pollen projects without too much trouble.

But there are some big differences, listed below, and they are just that --- differences, not
“improvements”. Punct’s inception as a personal, idiosyncratic convenience means it may be
more attractive than Pollen for projects with a particular set of priorities, and less attractive
in all other contexts.

@itemlist[

@item{Punct provides no project web server for previewing your HTML output. (You can use Pollen’s,
or use @link["https://github.com/samdphillips/raco-static-web"]{@tt{raco static-web}}.)}

@item{Punct provides no command-line tools for rendering output, and no templating
tools. (You can write Racket scripts for these things pretty easily. For templates in particular,
consider @secref["at-exp-lang" #:doc '(lib "scribblings/scribble/scribble.scrbl")].)}

@item{Punct provides no caching facilities. (You can, however, compile your source files with
@seclink["make" #:doc '(lib "scribblings/raco/raco.scrbl")]{@tt{raco make}} and/or use
a @link["https://www.gnu.org/software/make/manual/html_node/Introduction.html"]{makefile}.)}

@item{Punct does not provide a “preprocessor” dialect.}

@item{Punct does not offer any tools for ordering content, or for navigation. (But of course, you
can still use Pollen’s @seclink["Pagetree" #:indirect? #t #:doc '(lib
"pollen/scribblings/pollen.scrbl")]{pagetrees} or some scheme of your own.)}

@item{Punct generally eschews contracts and makes almost no effort to provide friendly error
messages.}

@item{Punct does not search through your filesystem for a @filepath{pollen.rkt} or other special
file to auto-require into your source files. This means there is also no “setup module” mechanism
for customizing Punct’s behavior.}

@item{Where Pollen’s documentation is generous and patient and does not assume any familiarity with
Racket, Punct’s documentation is clipped, and kind of assumes you know what you’re doing.}

]

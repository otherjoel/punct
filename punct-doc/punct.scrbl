#lang scribble/manual

@(require [for-label commonmark
                     punct/core
                     punct/doc
                     punct/fetch
                     punct/parse
                     punct/render/base
                     punct/render/html
                     punct/render/plaintext
                     racket/base
                     racket/class
                     racket/contract/base
                     racket/match
                     (only-in xml xexpr?)
                     (only-in txexpr txexpr? txexpr-tag? txexpr-attr? txexpr-element?)])

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

@subsection[#:tag "metas block"]{Metadata block}

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

@subsection{Markdown and Racket}

When evaluating a source file, Punct does things in this order:

@itemlist[#:style 'ordered

@item{The metadata block is parsed and its values added to @racket[current-metas].}

@item{Any inline Racket expressions are evaluated and replaced with their results. Tagged
X-expressions are preserved in the final document structure (see @secref{custom}). Any non-string
value other than a list, and any list beginning with something other than a symbol, is coerced into
a string.}

@item{The entire document is run through the @racketmodname[commonmark] parser, producing a
@racket[document] which is bound to @racketidfont{doc}.}

]

@section{Document Structure}

Because it uses the @racketmodname[commonmark] parser as a starting point, Punct documents come with
a default structure that is fairly opinionated. You can augment this structure if you understand how
the pieces fit together.

@defmodule[punct/doc]

The bindings provided by this module are also provided by @racketmodname[punct/core].

@defstruct[document ([metas hash-eq?] [body (listof block-element?)] [footnotes (listof block-element?)]) #:prefab]{

A Punct source file evaluates to a @racket[document] struct that includes a @racket[_metas] hash
table containing any metadata defined using the @secref{metas block}, @racket[?] or
@racket[set-meta]; and @racket[_body] and @racket[_footnotes], both of which are lists of
@tech{block elements}.

Behind the scenes: the @racketmodname[commonmark] parser produces a body and footnote definitions in
the form of nested structs. Punct converts both of these into lists of tagged X-expressions, to
allow for greater flexibility in adding @secref{custom}.

@history[#:changed "1.0" @elem{@racket[_body] and @racket[_footnotes] now guaranteed to be valid
X-expressions and not simply lists.}]

}

@subsection{Blocks and Flows}

@defproc[(block-element? (v any/c)) boolean?]{

A @deftech{block element} in Punct is a tagged X-expression which counts as a structural part of a
document: it starts with one of @racket['heading], @racket['paragraph], @racket['itemization],
@racket['item], @racket['blockquote], @racket['code-block], @racket['html-block],
@racket['footnote-definition] or @racket['thematic-break]. At the highest level, a document is a
sequence of these block elements.

@examples[#:label #f #:eval ev
(block-element? '(paragraph "Block party!"))
(block-element? "simple string")
]

A @deftech{flow} is a list of @tech{block elements}. The Markdown parser produces three block
elements that may contain flows: @racketid[blockquote], @racketid[item], and
@racketid[footnote-definition].

}

@deftogether[(
@defform[#:kind "txexpr" #:literals (level) (heading [[level lev-str]] content ...)
         #:contracts ([lev-str (or/c "1" "2" "3" "4" "5" "6")]
                      [content xexpr?])]

@defform[#:kind "txexpr" (paragraph content ...)
         #:contracts ([content xexpr?])]

@defform[#:kind "txexpr" #:literals (style start)
         (itemization [[style style-str] [start maybe-start]] item ...)
         #:contracts ([style-str (or/c "loose" "tight")]
                      [maybe-start (or/c "" string?)]
                      [item xexpr?])]

@defform[#:kind "txexpr" (item block ...)
         #:contracts ([block xexpr?])]

@defform[#:kind "txexpr" (blockquote block ...)
         #:contracts ([block block-element?])]

@defform[#:kind "txexpr" #:literals (info) (code-block [[info info-str]] content ...)
         #:contracts ([info-str string?]
                      [content xexpr?])]

@defform[#:kind "txexpr" (html-block content ...)
         #:contracts ([content xexpr?])]

@defform[#:kind "txexpr" #:literals (label ref-count)
         (footnote-definition [[label lbl] [ref-count rcount]] content ...)
         #:contracts ([lbl string?]
                      [rcount string?]
                      [content block-element?])]

@defform[#:kind "txexpr" (thematic-break)]

)]

@subsection{Inline elements}

@defproc[(inline-element? [v any/c]) boolean?]{

An @deftech{inline element} in Punct is a string, or any tagged X-expression that is not counted as
a @tech{block element}.

@examples[#:label #f #:eval ev
(inline-element? "simple string")
(inline-element? '(italic "emphasis"))
(inline-element? '(made-up-element "x"))
(inline-element? '(paragraph "Block party!"))
]

Inline elements that appear on a line by themselves (i.e., not marked up within block elements) are
automatically wrapped in @racketid[paragraph] elements.

}

Below is a list of the inline elements that can be produced by the Markdown parser.

@deftogether[(

@defform[#:kind "txexpr" (italic content ...)
         #:contracts ([content inline-element?])]

@defform[#:kind "txexpr" (bold content ...)
         #:contracts ([content inline-element?])]

@defform[#:kind "txexpr" #:literals (dest title) (link [[dest href] [title title-str]] content ...)
         #:contracts ([href string?]
                      [title-str string?]
                      [content inline-element?])]

@defform[#:kind "txexpr" (code content ...)
         #:contracts ([content inline-element?])]

@defform[#:kind "txexpr" #:literals (src title desc)
        (image [[src source] [title title-str] [desc description]])
        #:contracts ([source string?]
                     [title-str string?]
                     [description string?])]

@defform[#:kind "txexpr" (html content ...)
         #:contracts ([content inline-element?])]

@defform[#:kind "txexpr" #:literals (label defn-num ref-num)
        (footnote-reference [[label lbl] [defn-num dnum] [ref-num rnum]])
        #:contracts ([lbl string?]
                     [dnum string?]
                     [rnum string?])]

@defform[#:kind "txexpr" (line-break)]

)]

@subsection[#:tag "custom"]{Custom elements}

You can use Racket code to introduce new elements to the document’s structure.

A @deftech{custom element} is any list that begins with a symbol other than those produced by the
Markdown parser. 

A custom element may optionally have a set of @deftech{attributes}, which is a list of key/value
pairs that appears as the second item in the list. 

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

By default, Punct will treat custom elements as inline content.

If you want a custom element to count as a block (that is, to avoid having it auto-wrapped inside
a @tt{paragraph} element), you must give it a @racket['block] attribute with a value of either
@racket["root"] or @racket["single"]:

@itemlist[

@item{@racket["root"] should be used for blocks that might contain other block elements.
@bold{Limitations:} @racket["root"]-type blocks cannot be contained inside Markdown-created
@tech{flows} (such as block quotations notated using @litchar{>}); if found inside such a flow, they
will “escape” out to the root level of the document.}

@item{@racket["single"] should be used for block elements that might need to be contained within
Markdown-created @tech{flows}. @bold{Limitations:} @racket["single"]-type blocks must appear on
their own line or lines in order to be counted as blocks.}]

If that seems complicated, think of it this way: there are three kinds of @tech{flows} that you can
notate with Markdown: block quotes, list items, and footnote definitions. If your custom block
element might appear as a child of any of those three Markdown notations, you should probably start
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

@section{Rendering Output}

A Punct document is format-independent; when you want to use it in an output file, it must be
rendered into that output file’s format.

Punct currently includes an HTML renderer and a plain-text renderer. Both are based on a “base”
renderer. You can extend any Punct renderer or the base renderer to customize the process of
converting @racket[document]s to your target output format(s).

@subsection{Rendering HTML}

@defmodule[punct/render/html]

@defproc[(doc->html [pdoc document?] 
                    [fallback (-> txexpr-tag? 
                                  (listof txexpr-attr?) 
                                  (listof txexpr-element?) xexpr?) default-html-tag])
         string?]{

Renders @racket[_pdoc] into a string containing HTML markup. Each @tech{custom element} is passed to
@racket[_fallback], which must return an @racketlink[xexpr?]{X-expression}.

For more information on using the @racket[_fallback] argument to render custom elements, see
@secref["rendering-custom-elements"].

}

@defproc[(doc->html-xexpr [pdoc document?] 
                          [fallback (-> txexpr-tag? 
                                        (listof txexpr-attr?) 
                                        (listof txexpr-element?) xexpr?) default-html-tag])
         xexpr?]{

Renders @racket[_pdoc] into HTML, but in @racketlink[xexpr?]{X-expression} form rather than as a
string. Each @tech{custom element} is passed to @racket[_fallback], which must itself return an
X-expression.

For more information on using the @racket[_fallback] argument to render custom elements, see
@secref["rendering-custom-elements"].

}

@defproc[(default-html-tag [tag txexpr-tag?] 
                           [attributes (listof txexpr-attr?)] 
                           [elements (listof txexpr-element?)]) xexpr?]{

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
                         [fallback (-> txexpr-tag? 
                                       (listof txexpr-attr?) 
                                       (listof txexpr-element?) xexpr?)
                                   (make-plaintext-fallback line-width)])
                         string?]{

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

@subsection{Fetch}

@defmodule[punct/fetch]

@defproc[(get-doc [src path-string?]) document?]{

Returns the @racketidfont{doc} binding from @racket[_src]. No caching is used; this function is
basically a thin wrapper around @racket[dynamic-require]. If @racket[_src] does not exist, you will
get a friendly error message. If any other kind of problem arises, you will get an ugly error.

}

@defproc[(get-meta [doc document?]
                   [key symbol?]
                   [default failure-result/c (lambda () (raise (make-exn:fail ....)))])
         any/c]{

Returns the value of @racket[_key] in the @racket[document-metas] of @racket[_doc].
The value of @racket[_default] is used if the key does not exist: if it is a value, that value will be
returned instead; if it is a thunk, the thunk will be called.

@history[#:changed "1.1" @elem{Removed @racketidfont{get-doc-ref} and replaced with @racket[get-meta]}]

}

@defproc[(meta-ref [doc document?] [key symbol?]) any/c]{

Equivalent to @racket[(get-meta doc key #f)]. Provided for compatibility.
                                                         
}
         

@subsection{Parse}

@defmodule[punct/parse]

@defproc[(parse-markup-elements [metas hash-eq?]
                                [elements list]
                                [#:extract-inline? extract? #t]
                                [#:parse-footnotes? parse-fn? #f])
         (or/c document? (listof txexpr-element?))]{

Parses @racket[_elements] into a Punct AST by serializing everything as strings, sending the string
through the @racketmodname[commonmark] parser, and then converting the result into a Punct
@racket[document], reconstituting any @tech{custom elements} in the process.

If @racket[#:extract-inline?] is @racket[#true], and if the parsed document contains only a single
@tt{paragraph} element at the root level, then the elements inside the paragraph are returned as a
list (the paragraph is “shucked”). Otherwise, the entire result is returned as a @racket[document].

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

@item{Punct does not offer any tools for gathering multiple sources into ordered collections, or for
navigation between multiple sources. (But of course, you can still use Pollen’s @seclink["Pagetree"
#:indirect? #t #:doc '(lib "pollen/scribblings/pollen.scrbl")]{pagetrees} or some scheme of your
own.)}

@item{Punct generally eschews contracts and makes almost no effort to provide friendly error
messages.}

@item{Punct does not search through your filesystem for a @filepath{pollen.rkt} or other special
file to auto-require into your source files. This means there is also no “setup module” mechanism
for customizing Punct’s behavior.}

@item{Punct comes with a default, opinionated document structure. This might save you a bit of work,
but if you want full control over the structure of your document, you should use Pollen instead.}

@item{Pollen allows you to use any tag in your markup without defining it in advance. In Punct, this
will result in an error. (This may change in the future.)}

@item{Where Pollen’s documentation is generous and patient and does not assume any familiarity with
Racket, Punct’s documentation is clipped, and kind of assumes you know what you’re doing.}

]

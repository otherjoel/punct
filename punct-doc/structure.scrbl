#lang scribble/manual

@(require [for-label commonmark
                     punct/core
                     punct/doc
                     punct/element
                     racket/base
                     racket/contract/base
                     (only-in xml xexpr?)])

@(require scribble/examples "tools.rkt")
@(define ev (sandbox))
@(ev '(require punct/doc punct/parse punct/element))

@title{Document structure}

Because it uses the @racketmodname[commonmark] parser as a starting point, Punct documents come with
a default structure that is fairly opinionated. You can augment this structure if you understand how
the pieces fit together.

@declare-exporting[punct/doc punct/core]
@defmodule[punct/doc #:no-declare]

The bindings provided by this module are also provided by @racketmodname[punct/core].

@defstruct[document ([metas hash-eq?]
                     [body (listof block-element?)]
                     [footnotes (listof block-element?)]) #:transparent]{

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

@section{Blocks and Flows}

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
@defform[#:kind "txexpr" #:link-target? #f #:literals (level)
         (heading [[level lev-str]] content ...)
         #:contracts ([lev-str (or/c "1" "2" "3" "4" "5" "6")]
                      [content xexpr?])]

@defform[#:kind "txexpr" #:link-target? #f (paragraph content ...)
         #:contracts ([content xexpr?])]

@defform[#:kind "txexpr" #:link-target? #f #:literals (style start)
         (itemization [[style style-str] [start maybe-start]] item ...)
         #:contracts ([style-str (or/c "loose" "tight")]
                      [maybe-start (or/c "" string?)]
                      [item xexpr?])]

@defform[#:kind "txexpr" #:link-target? #f (item block ...)
         #:contracts ([block xexpr?])]

@defform[#:kind "txexpr" #:link-target? #f (blockquote block ...)
         #:contracts ([block block-element?])]

@defform[#:kind "txexpr" #:link-target? #f #:literals (info)
         (code-block [[info info-str]] content ...)
         #:contracts ([info-str string?]
                      [content xexpr?])]

@defform[#:kind "txexpr" #:link-target? #f (html-block content ...)
         #:contracts ([content xexpr?])]

@defform[#:kind "txexpr" #:link-target? #f #:literals (label ref-count)
         (footnote-definition [[label lbl] [ref-count rcount]] content ...)
         #:contracts ([lbl string?]
                      [rcount string?]
                      [content block-element?])]

@defform[#:kind "txexpr" #:link-target? #f (thematic-break)]

)]

@section{Inline elements}

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

@defform[#:kind "txexpr" #:link-target? #f (italic content ...)
         #:contracts ([content inline-element?])]

@defform[#:kind "txexpr" #:link-target? #f (bold content ...)
         #:contracts ([content inline-element?])]

@defform[#:kind "txexpr" #:link-target? #f #:literals (dest title)
         (link [[dest href] [title title-str]] content ...)
         #:contracts ([href string?]
                      [title-str string?]
                      [content inline-element?])]

@defform[#:kind "txexpr" #:link-target? #f (code content ...)
         #:contracts ([content inline-element?])]

@defform[#:kind "txexpr" #:link-target? #f #:literals (src title desc)
        (image [[src source] [title title-str] [desc description]])
        #:contracts ([source string?]
                     [title-str string?]
                     [description string?])]

@defform[#:kind "txexpr" #:link-target? #f (html content ...)
         #:contracts ([content inline-element?])]

@defform[#:kind "txexpr" #:link-target? #f #:literals (label defn-num ref-num)
        (footnote-reference [[label lbl] [defn-num dnum] [ref-num rnum]])
        #:contracts ([lbl string?]
                     [dnum string?]
                     [rnum string?])]

@defform[#:kind "txexpr" #:link-target? #f (line-break)]

)]

@section[#:tag "custom"]{Custom elements}

You can use Racket code to introduce new elements to the document's structure.

A @deftech{custom element} is any list that begins with a symbol, and which was produced by inline
Racket code rather than by parsed Markdown syntax.

@margin-note{If you think "custom elements" sound like Pollen "tags", you are correct. I use "custom
elements" rather than "tags" or "X-expressions" to distinguish them from from Markdown-generated
elements; also, unlike Pollen tags, custom elements may be treated differently depending on their
@tech{block attributes}.}

A custom element may optionally have a set of @deftech{attributes}, which is a list of key/value
pairs that appears as the second item in the list.

Here is an example of a function that produces a custom @tt{abbreviation} element with a @tt{term}
attribute:

@codeblock|{
#lang punct

•(define (abbr term . elems)
   `(abbreviation [[term ,term]] ,@elems))

Writing documentation in Javascript? •abbr["Laugh out loud"]{LOL}.
}|

Produces:

@racketblock[
(document
 '#hasheq((here-path . "126-unsaved-editor"))
 '((paragraph
    "Writing documentation in Javascript? "
    (abbreviation ((term "Laugh out loud")) "LOL")
    "."))
 '())
]

By default, Punct will treat custom elements as @tech{inline elements}: they will be wrapped inside
@tt{paragraph} elements if they occur on their own lines.

You can set a custom element's @deftech{block attribute} to force Punct to treat it as a block
element (that is, to avoid having it auto-wrapped inside a @tt{paragraph} element): simply give it a
@racket['block] attribute with a value of either @racket["root"] or @racket["single"]:

@itemlist[

@item{@racket["root"] should be used for blocks that might contain other block elements.
@bold{Limitations:} @racket["root"]-type blocks cannot be contained inside Markdown-created
@tech{flows} (such as block quotations notated using @litchar{>}); if found inside such a flow, they
will "escape" out to the root level of the document.}

@item{@racket["single"] should be used for block elements that might need to be contained within
Markdown-created @tech{flows}. @bold{Limitations:} @racket["single"]-type blocks must appear on
their own line or lines in order to be counted as blocks.}]

If that seems complicated, think of it this way: there are three kinds of @tech{flows} that you can
notate with Markdown: block quotes, list items, and footnote definitions. If your custom block
element might appear as a child of any of those three Markdown notations, you should probably start
by giving it the @racket['(block "single")] attribute.

You'll never get an error for using the wrong @racket['block] type on your custom elements; you'll
just get unexpected results in the structure of your document.

@bold{Under the hood:} The two types of blocks above correspond to two methods Punct uses to trick
the CommonMark parser into treating custom elements as blocks. With @racket["root"]-type blocks,
Punct inserts extra line breaks (which is what causes these blocks to "escape" out of Markdown
blockquotes to the document's root level, just as it would if you typed two linebreaks in your
source). With @racket["single"]-type blocks, Punct allows CommonMark to wrap the element in a
@tt{paragraph}, then looks for any paragraph that contains @emph{only} a @racket["single"]-type
block and "shucks" them out of their containing paragraphs. The need for such tricks comes from a
design decision to use the @racketmodname[commonmark] package exactly as published, without forking
or customizing it in any way.

@subsection[#:tag "custom-element-conveniences"]{Custom element conveniences}

If you make much use of @tech{custom elements}, you will probably find yourself writing several
functions that do nothing but lightly rearrange the arguments into an X-expression:

@racketblock[
(define (abbr term . elems)
   `(abbrevation [[term ,term]] ,@elems))
]

To cut down on the repetition, you can use @racket[default-element-function] to create a function
that automatically parses keyword arguments into attributes:

@codeblock{
#lang punct
•(define abbr (default-element-function 'abbreviation))

•abbr[#:term "Laugh Out Loud"]{LOL}  •; -→ '(abbreviation ((term "Laugh Out Loud")) "LOL")
}

You can simplify this even further with @racket[define-element]:

@codeblock{
#lang punct
•(define-element abbr)

•abbr[#:term "Laugh Out Loud"]{LOL}  •; -→ '(abbr ((term "Laugh Out Loud")) "LOL")
}

Both @racket[default-element-function] and @racket[define-element] allow shorthand for setting
default @tech{block attributes} and defaults for the @racket['class] attribute. See their entries in
module reference for more details.

@codeblock{
#lang punct
•(define-element note box§.warning #:title "WATCH IT")

•note{Wet floor!}
•; -→ '(box ((block "root") (class "warning") (title "WATCH IT") "Wet floor!")
}

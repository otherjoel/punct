#lang scribble/manual

@(require [for-label punct/core
                     racket/base])

@title{Writing Punct}

Start your Punct source file with @racketmodfont{#lang punct}. Then just write in
CommonMark-flavored Markdown.

Punct allows inline Racket code that follows @secref["reader" #:doc '(lib
"scribblings/scribble/scribble.scrbl")] but with the @litchar{•} "bullet" character (@tt{U+2022}) as
the control character instead of @litchar{@"@"}.  On Mac OS, you can type this using @tt{ALT+8}.

Punct source files automaticaly @racket[provide] two bindings: @racketidfont{doc} (a
@racket[document]) and @racketidfont{metas} (a hash table).

@section{Using @racket[require]}

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

@section[#:tag "metas block"]{Metadata block}

Sources can optionally add metadata using @racketvalfont{key: value} lines, delimited by lines
consisting only of consecutive hyphens:

@codeblock{
 #lang punct
 ---
 title: Prepare to be amazed
 date: 2020-05-07
 draft?: '#t
 ---

 Regular content goes here
}

This is a syntactic convenience that comes with a few rules and limitations:

@itemlist[#:style 'compact

@item{The metadata block must be the first non-whitespace thing that follows the
@racketmodfont{#lang} line.}

@item{Each value will always be parsed as a flat string --- or, if prefixed with a single quote
@litchar{'}, as a simple datum (using @racket[read]). If more than one datum appears after the
@litchar{'}, the first will be used and the rest discarded.}

]

Prefixing meta values with @litchar{'} allows you to store booleans and numbers, as well as complex
values like lists, vectors, hash tables, or anything else that @racket[read] would count as a single
datum (and which fits in one line) --- but note that code inside the value will not be evaluated.

If you want to use the results of expressions in your metadata, you can use the @racket[set-meta]
function anywhere in the document or in code contained in other modules. Within the document body
you can also use the @racket[?] macro as shorthand for @racket[set-meta].

@history[#:changed "1.2" @elem{Added ability to use datums quoted with @litchar{'} in metadata.}]

@section{Markdown and Racket}

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

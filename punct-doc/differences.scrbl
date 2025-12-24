#lang scribble/manual

@title{Differences from Pollen}

Punct is heavily indebted to @seclink["top" #:indirect? #t #:doc '(lib
"pollen/scribblings/pollen.scrbl")]{Pollen}.  Much of its design and code comes from Pollen. And
because Punct sources provide bindings for @racketidfont{doc} and @racketidfont{metas} just like
Pollen markup sources do, you should be able to use Punct sources in Pollen projects without too
much trouble.

But there are some big differences, listed below, and they are just that --- differences, not
“improvements”. Punct’s inception as a personal, idiosyncratic convenience with different goals
means it may be more attractive than Pollen for projects with a particular set of priorities, and
less attractive in all other contexts.

@itemlist[

@item{Punct provides no project web server for previewing your HTML output. (You can use Pollen's,
or use @link["https://github.com/samdphillips/raco-static-web"]{@tt{raco static-web}}.)}

@item{Punct provides no command-line tools for rendering output, and no templating
tools. (You can write Racket scripts for these things pretty easily. For templates in particular,
consider @secref["at-exp-lang" #:doc '(lib "scribblings/scribble/scribble.scrbl")].)}

@item{Punct provides no caching facilities. (You can, however, compile your source files with
@seclink["make" #:doc '(lib "scribblings/raco/raco.scrbl")]{@tt{raco make}} and/or use
a @link["https://www.gnu.org/software/make/manual/html_node/Introduction.html"]{makefile}.)}

@item{Punct does not provide a “preprocessor” dialect.}

@item{Punct does not offer any tools for gathering multiple sources into ordered collections, or for
navigation between multiple sources. (But of course, you can still use Pollen's @seclink["Pagetree"
#:indirect? #t #:doc '(lib "pollen/scribblings/pollen.scrbl")]{pagetrees} or some scheme of your
own.)}

@item{Punct generally eschews contracts and makes almost no effort to provide friendly error
messages.}

@item{Punct does not search through your filesystem for a @filepath{pollen.rkt} or other special
file to auto-require into your source files. This means there is also no "setup module" mechanism
for customizing Punct's behavior.}

@item{Punct comes with a default, opinionated document structure. This might save you a bit of work,
but if you want full control over the structure of your document, you should use Pollen instead.}

@item{Pollen allows you to use any tag in your markup without defining it in advance. In Punct, this
will result in an error.}

@item{Pollen allows you to define a function (@racket[root]) which gives you the chance for a final
pass over the doc’s entire X-expression. In Punct it’s expected that you’ll do this kind of thing at
the point where you render a @racket[document] to its final output format; or that, when you need
deep control over the format-independent AST, you’ll be @secref["extending-renderer"].}

@item{Where Pollen's documentation is generous and patient and does not assume any familiarity with
Racket, Punct's documentation is clipped, and kind of assumes you know what you're doing.}

]

#lang scribble/manual

@(require [for-label commonmark
                     (only-in xml xexpr?)]
          "tools.rkt")

@title[#:style '(toc)]{Punct: CommonMark + Racket}
@author{@elem{Joel Dueck (@hyperlink["https://joeldueck.com"]{@tt{joeldueck.com}})}}

@defmodulelang[punct]

Punct is a programming environment for publishing things, implemented in Racket. Punct's two basic
ideas are:

@itemlist[#:style 'ordered

@item{Markdown documents (parsed by @racketmodname[commonmark]), extensible with Racket code.}

@item{Multiple output formats. A Punct program/document produces a format-independent AST that can
be rendered to HTML, @Typst (for PDF), or plain text. You can also extend Punct to render to other
formats.}]

The latest version of this documentation can be found at
@link["https://joeldueck.com/what-about/punct/"]{@tt{joeldueck.com}}. The source and installation
instructions are at the project's @link["https://github.com/otherjoel/punct"]{GitHub repo}.

@margin-note{If you decide to rely on Punct in any kind of "production" capacity, you should make
sure to monitor the @link["https://github.com/otherjoel/punct/pulls"]{pull requests} and
@link["https://github.com/otherjoel/punct/discussions/categories/announcements"]{Announcements}
areas of the GitHub repository. Any significant changes will be announced there first.}

@youtube-embed-element["https://www.youtube.com/embed/9zxna1tlvHU"]

I have designed Punct for my own use and creative needs. If you would like Punct to work differently
or support some new feature, I encourage you to fork it and customize it yourself.

This documentation assumes you are familiar with Racket, and with @racketlink[xexpr?]{X-expressions}
and associated terms (attributes, elements, etc).

@callout{If you use Punct in your project, @hyperlink["mailto:joel@jdueck.net"]{email Joel} to
introduce yourself! This is the sole condition of the project's
@hyperlink["https://github.com/otherjoel/punct/blob/main/LICENSE.md"]{permissive license.} (See
@hyperlink["https://joeldueck.com/how-i-license.html"]{How I License} for background.)}

@local-table-of-contents[]

@include-section["quickstart.scrbl"]

@include-section["writing.scrbl"]

@include-section["structure.scrbl"]

@include-section["strategies.scrbl"]

@include-section["reference.scrbl"]

@include-section["differences.scrbl"]

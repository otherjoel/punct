# Punct

Punct is a programming environment for publishing things, implemented in Racket. It uses inline
Racket code to extend CommonMark-flavored Markdown, which is parsed into a format-independent AST
that can be rendered in HTML (or any other target file type).

**Documentation is at <https://joeldueck.com/what-about/punct/>**.

**If you decide to rely on Punct in “production”, you should monitor the [Announcements][a] area of
this repository. Any significant or breaking changes will be announced there first.**

[a]: https://github.com/otherjoel/punct/discussions/categories/announcements

## Installation

Clone this repository, and from within the checkout’s root folder, do `raco pkg install --link
punct-lib/ punct-doc/` (note the trailing slashes).

Once this is done, try it out by following along with the [Quick Start][qs].

[qs]: https://joeldueck.com/what-about/punct/Quick_start.html


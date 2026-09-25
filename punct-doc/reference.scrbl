#lang scribble/manual

@(require [for-label punct/core
                     punct/doc
                     punct/element
                     punct/fetch
                     punct/parse
                     punct/render/base
                     punct/render/html
                     punct/render/plaintext
                     punct/render/typst
                     racket/base
                     racket/class
                     racket/contract/base
                     racket/match
                     (only-in xml xexpr? xexpr->string)])

@(require scribble/examples "tools.rkt")
@(define ev (sandbox))
@(ev '(require punct/doc punct/parse punct/element))

@title[#:style 'toc]{Module Reference}

@table-of-contents[]

@section{Core}

@defmodule[punct/core]

@defparam[current-metas metas (or/c hash-eq? #f)]{

A parameter that, during compilation of a Punct source, holds the metadata hash table for that file.
The final value of this parameter becomes the value of @racket[document-metas] for that file's
@racketidfont{doc} as well as its @racketidfont{metas} export.

The only key automatically defined in every metadata table is @racket['here-path], which holds the
absolute path to the source file.

If no Punct file is currently being compiled, this parameter will hold @racket[#f] by default. In
particular, this parameter is @emph{not} automatically set to a Punct file's @racketidfont{metas}
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

@section{Elements}

@declare-exporting[punct/element punct/core]
@defmodule[punct/element #:no-declare]

The bindings documented in this section are also provided by @racketmodname[punct/core]. The
bindings in @secref["element-structure"] are provided only by @racketmodname[punct/element].

@defproc[(default-element-function [tag symbol?]
                                   [default-attr-kw keyword?]
                                   [default-attr-val string?] ...)
         (->* () #:rest any/c xexpr?)]{

Returns a function which produces a @racket[_tag] @tech{custom element}. This function takes any
number of keyword arguments (which are converted to attributes) and non-keyword arguments (which
become the child elements of this returned element).

You can also give keyword/value arguments to @racket[default-element-function] itself; these will be
set as default attributes/values in the custom element returned by the resulting function.

@examples[#:eval ev
          (define aside (default-element-function 'aside))
          (aside "Hello")
          (define kbd (default-element-function 'kbd #:alt "foo"))
          (kbd "CTRL")
          (kbd "CTRL" #:data-code "1")
          ]

If a keyword argument supplied at the call site has the same name as one of the default attributes, the
call-site value overrides the default rather than duplicating it:

@examples[#:eval ev
          (define span (default-element-function 'span #:class "default"))
          (span "with default" #:id "a")
          (span "overridden" #:class "custom")]

Attribute values must be strings. A keyword argument whose value is @racket[#f] is left out, which
makes it easy to include an attribute only some of the time, and to remove a default at the call
site. Any other value raises an error.

@examples[#:eval ev
          (span "no class" #:class #f)
          (eval:error (span "count" #:count 3))]

@margin-note{On Mac OS, type @tt{ALT+6} to produce @litchar{§} and @tt{ALT+7} to produce @litchar{¶}.}

If @racket[tag] ends in either @litchar{§} or @litchar{¶}, the resulting function will add a default
@tech{block attribute} of @racket{root} or @racket{single} respectively:

@examples[#:eval ev
          (define info (default-element-function 'info§))
          (info "Note!")
          (define mypar (default-element-function 'mypar¶))
          (mypar "Walnuts")]

If @racket[tag] has a suffix of the form @racketidfont{.foo}, the resulting function will add a default
@racket['class] attribute whose value is set to @racket{foo}. Multiple such suffixes will add
additional values to the @racket['class] attribute.

@examples[#:eval ev
          (define carton (default-element-function 'carton.xyz.abc))
          (carton "Cashews")
          (define crate (default-element-function 'crate¶.foo))
          (crate "Pecans")]

@history[#:added "1.3"
         #:changed "1.5" @elem{Keyword arguments with a value of @racket[#f] are left out; other
         values that are not strings raise an error.}]

}

@defform*[[(define-element id [default-attr-kw default-attr-val ...])
           (define-element id tag [default-attr-kw default-attr-val ...])]
          #:contracts ([default-attr-kw keyword?]
                       [default-attr-val string?])]{

Shorthand macro for @racket[default-element-function].

If @racket[tag] is supplied, it is used as the tag for the X-expressions generated by the resulting
function:

@examples[#:eval ev #:label #f
          (define-element bowl container.bowl)
          (bowl "Corn nuts")
          (define-element jar vessel¶ #:type "Glass")
          (jar "Chestnuts")]

If @racket[tag] is not supplied, the first argument is used both as the identifier for the function
and for the tag in generated X-expressions:

@examples[#:eval ev #:label #f
          (define-element bag.xyz.abc)
          (bag "Sunflower seeds")
          (define-element packet¶.foo)
          (packet "Raisins")]

As with @racket[default-element-function], keyword arguments at the call site override any matching
defaults:

@examples[#:eval ev #:label #f
          (define-element note aside§ #:class "info")
          (note "A note")
          (note "A warning" #:class "warning")]

@history[#:added "1.3"]

}

@defproc[(ref-attr [attrs (listof attr?)] [key symbol?] [default any/c #f]) any/c]{

Returns the value of the @racket[_key] attribute in @racket[_attrs], or @racket[_default] if there is
no such attribute. This is useful in a @tech{fallback function}, which receives the attributes of an
element as a separate list.

@examples[#:eval ev
          (ref-attr '((class "info") (id "a")) 'id)
          (ref-attr '((class "info")) 'id)
          (ref-attr '((class "info")) 'id "none")]

@history[#:changed "1.5" @elem{Added the @racket[_default] argument.}]

}

@subsection[#:tag "element-structure"]{Working with elements}

@declare-exporting[punct/element]

These functions take apart, change and search the @tech{elements} produced by Punct's parse.
They follow the same rules Punct uses everywhere:

@itemlist[
@item{An @deftech{element} is any non-empty list whose first item is a symbol (its @deftech{tag}).}
@item{If the second item is a list of attributes (each a two-item list of a symbol and a string),
it is the element's attribute list. Everything after that is a child.}
@item{Children are not checked: they can be strings, other elements, or any other values.}
]

@callout{In the interests of speed, the implementations of these functions do not use contracts or
check their arguments. The signatures below describe what each function expects; if you give it
something else, expect error messages.}

@callout{Note that the @racketmodname[xml] library also provides bindings named @tt{element},
@tt{element?} and @tt{make-element}. If you need both libraries in one module, use @racket[only-in] or
@racket[prefix-in] for one of them.}

@defproc[(element? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[_v] is a non-empty list whose first item is a symbol.

@examples[#:eval ev
          (element? '(p "Hello"))
          (element? '(br))
          (element? "Hello")
          (element? '())]

@history[#:added "1.5"]

}

@defproc[(attr? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[_v] is a two-item list of a symbol and a string.

@examples[#:eval ev
          (attr? '(class "info"))
          (attr? '(count 3))]

@history[#:added "1.5"]

}

@defproc[(element-parts [elem element?]) (values symbol? (listof attr?) list?)]{

Returns the tag, attributes and children of @racket[_elem]. The attributes are @racket['()] if
@racket[_elem] has none.

A list in the second position that has a value that is not a string is not an attribute list, so it
is returned as the first child.

@examples[#:eval ev
          (element-parts '(p ((class "x")) "a" (em "b")))
          (element-parts '(p "a"))
          (element-parts '(p ((count 3)) "a"))]

@history[#:added "1.5"]

}

@defproc[(make-element [tag symbol?] [attrs (listof attr?) '()] [children list? '()]) element?]{

Builds an element. If @racket[_attrs] is empty, it is left out.

@examples[#:eval ev
          (make-element 'p '((class "x")) '("a"))
          (make-element 'p '() '("a"))]

@history[#:added "1.5"]

}

@deftogether[(@defproc[(element-tag [elem element?]) symbol?]
              @defproc[(element-attrs [elem element?]) (listof attr?)]
              @defproc[(element-children [elem element?]) list?])]{

Return one part of @racket[_elem]. See @racket[element-parts].

@history[#:added "1.5"]

}

@defproc[(set-attr [attrs (listof attr?)] [key symbol?] [val string?]) (listof attr?)]{

Returns @racket[_attrs] with the @racket[_key] attribute set to @racket[_val]. An existing attribute
keeps its position; a new one is added at the end.

@examples[#:eval ev
          (set-attr '((href "/x") (title "X")) 'href "/y")
          (set-attr '((href "/x")) 'rel "external")]

@history[#:added "1.5"]

}

@defproc[(remove-attr [attrs (listof attr?)] [key symbol?]) (listof attr?)]{

Returns @racket[_attrs] without the @racket[_key] attribute.

@examples[#:eval ev
          (remove-attr '((id "a") (class "x")) 'id)]

@history[#:added "1.5"]

}

@defproc[(element-map [proc (-> any/c any/c)] [v any/c]) any/c]{

Calls @racket[_proc] on @racket[_v] and every node inside it, children first, and builds a new tree
from the results. Because children are done first, @racket[_proc] receives each element with its
children already replaced. @racket[_proc] receives strings and other non-element values too, but
never attribute lists.

@examples[#:eval ev
          (element-map (λ (x) (if (string? x) (string-upcase x) x))
                       '(p ((class "x")) "a" (em "b")))
          (require racket/match)
          (element-map (match-lambda
                         [(element 'a attrs kids) (make-element 'a (set-attr attrs 'rel "external") kids)]
                         [x x])
                       '(p "See " (a ((href "https://example.com")) "this")))]

@history[#:added "1.5"]

}

@deftogether[(@defproc[(element-find [pred (-> element? any/c)] [v any/c]) (or/c element? #f)]
              @defproc[(element-find* [pred (-> element? any/c)] [v any/c]) (listof element?)])]{

Search @racket[_v] and the elements inside it, in document order: a parent comes before its
children. Only elements are passed to @racket[_pred]. @racket[element-find] returns the first
element for which @racket[_pred] returns a true value, or @racket[#f]; @racket[element-find*] returns
all of them, or @racket['()].

@examples[#:eval ev
          (define (link? e) (eq? (element-tag e) 'link))
          (define body '(paragraph (link ((dest "/a")) "A") " and " (bold (link ((dest "/b")) "B"))))
          (element-find link? body)
          (element-find* link? body)
          (element-find* (λ (e) (eq? (element-tag e) 'table)) body)]

@history[#:added "1.5"]

}

@defform[#:kind "match expander" (element tag-pat attrs-pat children-pat)]{

Matches an element, and matches its tag, attributes and list of children against the three
patterns. @racket[_attrs-pat] is matched against @racket['()] if the element has no attributes.

@examples[#:eval ev
          (match '(a ((href "/x")) "X")
            [(element 'a (list-no-order (list 'href url) _ ...) kids) (list url kids)])
          (match '(p "Hello")
            [(element tag '() kids) (list tag kids)])]

@history[#:added "1.5"]

}

@section{Fetch}

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


@section{Parse}

@defmodule[punct/parse]

@defproc[(parse-markup-elements [metas hash-eq?]
                                [elements list]
                                [#:extract-inline? extract? #t]
                                [#:parse-footnotes? parse-fn? #f])
         (or/c document? (listof xexpr?))]{

Parses @racket[_elements] into a Punct AST by serializing everything as strings, sending the string
through the @racketmodname[commonmark] parser, and then converting the result into a Punct
@racket[document], reconstituting any @tech{custom elements} in the process.

If @racket[#:extract-inline?] is @racket[#true], and if the parsed document contains only a single
@tt{paragraph} element at the root level, then the elements inside the paragraph are returned as a
list (the paragraph is "shucked"). Otherwise, the entire result is returned as a @racket[document].

The @racket[#:parse-footnotes?] argument determines whether the @racketmodname[commonmark] parser
will parse Markdown-style footnote references and definitions in @racket[_elements].

@examples[#:eval ev

(define elems
  '("# Title\n\nA paragraph with *italic* text, and "
    1
    (custom "custom element")))
(parse-markup-elements (hasheq) elems)]

}

@section[#:tag "rendering-api"]{Rendering}

Punct currently includes renderers for HTML, Typst, and plain-text. These are based on a "base"
renderer class that you can extend to customize the rendering process or to target new output formats.

@subsection[#:tag "rendering-custom-elements"]{Rendering custom elements}

When rendering your document to a specific output format (such as HTML) Punct has to decide how to
render any @tech{custom elements} introduced by your code. When Punct encounters a custom element,
it passes it to a @deftech{fallback function}: the fallback function receives three arguments: the
custom element’s tag, its attributes, and a list of sub-elements found inside the element. The
sub-elements will already have been fully processed by Punct.

A separate @tech{fallback function} is needed for each output format you want to target. Punct
provides default fallback functions the target output format it supports natively. For example, when
targeting HTML, Punct defaults to @racket[default-html-tag], which simply converts custom elements
to HTML elements. If you want more customized behavior, you'll need to provide your own fallback
procedure to the renderer.

Here's an example pair of functions for rendering documents containing the custom @tt{abbreviation}
element (from the examples above) into HTML:

@racketblock[

(define (custom-html tag attrs elems)
  (match (list tag attrs)
    [`(abbreviation [[term ,term]]) `(abbr [[title ,term]] ,@elems)]))

(define (my-html-renderer source-path)
  (doc->html (get-doc source-path) custom-html))

]

@subsection{HTML}

@defmodule[punct/render/html]

@defproc[(doc->html [pdoc document?]
                    [fallback (-> symbol?
                                  (listof (list/c symbol? string?))
                                  (listof xexpr?)
                                  xexpr?) default-html-tag])
         string?]{

Renders @racket[_pdoc] into a string containing HTML markup. Each @tech{custom element} is passed to
@racket[_fallback], which must return an @racketlink[xexpr?]{X-expression}.

This function uses @racket[xexpr->string] to generate the HTML string. This function will blindly
escape characters inside @racketoutput{<script>} and @racketoutput{<style>} tags, which may
introduce errors. For HTML output that is friendlier and more correct, consider using the
@racketmodname[html-printer #:indirect] package in concert with @racket[doc->html-xexpr].

For more information on using the @racket[_fallback] argument to render custom elements, see
@secref["rendering-custom-elements"].

}

@defproc[(doc->html-xexpr [pdoc document?]
                          [fallback (-> symbol?
                                        (listof (list/c symbol? string?))
                                        (listof xexpr?)
                                        xexpr?) default-html-tag])
         xexpr?]{

Renders @racket[_pdoc] into HTML, but in @racketlink[xexpr?]{X-expression} form rather than as a
string. Each @tech{custom element} is passed to @racket[_fallback], which must itself return an
X-expression.

For more information on using the @racket[_fallback] argument to render custom elements, see
@secref["rendering-custom-elements"].

}

@defproc[(default-html-tag [tag symbol?]
                           [attributes (listof (list/c symbol? string?))]
                           [elements (listof xexpr?)])
         xexpr?]{

Returns an X-expression comprised of @racket[_tag], @racket[_attributes] and @racket[_elements].
Mainly used as the default @tech{fallback function} for @racket[doc->html].

@examples[#:eval ev
(require punct/render/html)
(default-html-tag 'kbd '() '("Enter"))
(default-html-tag 'a '((href "http://example.com")) '("Link"))
]
}

@defclass[punct-html-render% punct-abstract-render% ()]{

The HTML renderer class. Extends @racket[punct-abstract-render%] to produce HTML output.
You can extend this class to customize HTML rendering behavior.

See @secref["extending-renderer"] for examples of extending the HTML renderer.

}

@subsection{Typst}

@defmodule[punct/render/typst]

@link["https://typst.app"]{Typst} is a modern typesetting system designed as an alternative to LaTeX.
This renderer produces Typst markup from Punct documents.

@defproc[(doc->typst [pdoc document?]
                     [fallback (symbol? (listof (listof symbol? string?)) list? . -> . string?)
                               default-typst-tag]) string?]{

Renders @racket[_pdoc] into a string containing Typst markup. Any @tech{custom elements} are passed
to @racket[_fallback], which must return a string.

Markdown/Punct elements are mapped to Typst syntax as follows:

@tabular[#:style 'boxed
         #:column-properties '(left left)
         #:row-properties '(bottom-border ())
  (list (list @bold{Punct element} @bold{Typst output})
        (list "Headings" @elem{@elem[#:style 'tt]{@literal{= Heading}} (with levels as @tt{=} count)})
        (list "Bold" @elem[#:style 'tt]{@literal{*text*}})
        (list "Italic" @elem[#:style 'tt]{@literal{_text_}})
        (list "Inline code" @elem[#:style 'tt]{@literal{`code`}})
        (list "Code blocks" @elem[#:style 'tt]{@literal{```lang ... ```}})
        (list "Links" @elem[#:style 'tt]{@literal{#link("url")[text]}})
        (list "Images" @elem[#:style 'tt]{@literal{#image("path")}})
        (list "Bullet lists"@elem[#:style 'tt]{ @literal{- item}})
        (list "Numbered lists" @elem[#:style 'tt]{@literal{+ item}})
        (list "Block quotes"@elem[#:style 'tt]{@literal{#quote(block: true)[...]}})
        (list "Footnotes" @elem{@elem[#:style 'tt]{@literal{#footnote[...]}} (inline)}))]

Typst special characters (@litchar{*}, @litchar{_}, @litchar{`}, @litchar{#},
@litchar["@"], @litchar{$}, @litchar{[}, @litchar{]}) in text content are automatically escaped,
allowing the same Punct source to target both HTML and Typst without manual escaping. Content inside
code blocks and inline code is not escaped, as Typst renders these literally.

For more information on using the @racket[_fallback] argument to render custom elements, see
@secref["rendering-custom-elements"].

@history[#:added "1.4"]

}

@defproc[(default-typst-tag [tag symbol?] [attributes (listof (listof symbol? string?))] [elements list?]) string?]{

Returns a Typst function call string using @racket[_tag], @racket[_attributes], and @racket[_elements].
Mainly used as the default @tech{fallback function} for @racket[doc->typst].

The output format is @tt{#tag(attr: "val", ...)[content]}, where attributes become named arguments
with string values, and elements become a trailing content block. When there are no attributes,
the parentheses are omitted: @tt{#tag[content]}. When there are no elements, the content block
is omitted: @tt{#tag(attr: "val")}.

Hyphens in @racket[_tag] and attribute names are converted to underscores to produce valid Typst
identifiers (e.g., @racket['my-element] becomes @tt{my_element}).

Note that @racket[_elements] are already escaped when passed to the fallback. Attribute values
are automatically escaped and quoted as Typst strings.

@examples[#:eval ev
(require punct/render/typst)
(default-typst-tag 'note '() '("Important!"))
(default-typst-tag 'note '((class "info")) '("Important!"))
(default-typst-tag 'my-spacer '((line-height "2em")) '())
]

@history[#:added "1.4"]

}

@defproc[(escape-typst-text [str string?]) string?]{

Escapes special Typst characters (@litchar{*}, @litchar{_}, @litchar{`}, @litchar{#},
@litchar["@"], @litchar{$}, @litchar{[}, @litchar{]}, @litchar{\}) in @racket[_str] by
prefixing them with backslashes. Use this for text content in custom fallback procedures.

@history[#:added "1.4"]

}

@defproc[(escape-typst-string [str string?]) string?]{

Escapes backslashes and double quotes in @racket[_str] for use within quoted Typst strings
(e.g., URLs or file paths in function arguments like @tt{#link("...")} or @tt{#image("...")}).

@history[#:added "1.4"]

}

@defclass[punct-typst-render% punct-abstract-render% ()]{

The Typst renderer class. Extends @racket[punct-abstract-render%] to produce Typst markup output.
You can extend this class to customize Typst rendering behavior.

@history[#:added "1.4"]

}

@subsection{Plain text}

@defmodule[punct/render/plaintext]

Sometimes you want to convert a document into a text format that is even plainer than Markdown, such
as when generating the plaintext version of an email newsletter.

@defproc[(doc->plaintext [pdoc document?]
                         [line-width exact-nonnegative-integer?]
                         [fallback (-> symbol?
                                       (listof (list/c symbol? string?))
                                       (listof xexpr?)
                                       xexpr?)
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

@item{Images are replaced with their "alt" text, prefixed by @racket["Image: "] and wrapped in
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

@subsection{Base renderer}

@defmodule[punct/render/base]

@defclass[punct-abstract-render% object% ()]{

The abstract base class for all Punct renderers. To create a custom renderer, extend this class
and implement all abstract methods. The built-in HTML, Typst, and plaintext renderers all
extend this class.

@defconstructor[([doc document?]
                 [render-fallback (-> symbol?
                                      (listof (list/c symbol? string?))
                                      list?
                                      any/c)])]{
Creates a new renderer instance. The @racket[doc] argument is the Punct document to render.
The @racket[render-fallback] procedure is called for any @tech{custom elements} encountered
during rendering.
}

@defmethod[(render-document) any/c]{
The main entry point for rendering. Calls the appropriate rendering methods for each element
in the document body and footnotes.

The default implementation returns two values: a list of rendered body elements and a list
of rendered footnotes. Subclasses typically override this to combine these into a single
output value (e.g., a string or X-expression).
}

@defmethod[(render-string [s string?]) any/c]{
Called for every string in the document. Override this to transform raw text (e.g., for
escaping special characters in the target format). The default implementation returns
the string unchanged.A

@history[#:added "1.4"]

}

To create a custom renderer, extend this class and implement all of the abstract methods below.

@margin-note{See @secref["extending-renderer"] for examples of extending the base renderer.}

@defmethod[(render-thematic-break) any/c]
@defmethod[(render-heading [level string?] [rendered-elems list?]) any/c]
@defmethod[(render-code-block [info-string string?] [raw-elems list?]) any/c]
@defmethod[(render-html-block [raw-content any/c]) any/c]
@defmethod[(render-paragraph [rendered-elems list?]) any/c]
@defmethod[(render-blockquote [rendered-elems list?]) any/c]
@defmethod[(render-itemization [style string?] [start string?] [rendered-items list?]) any/c]
@defmethod[(render-item [rendered-elems list?]) any/c]
@defmethod[(render-line-break) any/c]
@defmethod[(render-bold [rendered-elems list?]) any/c]
@defmethod[(render-italic [rendered-elems list?]) any/c]
@defmethod[(render-code [raw-elems list?]) any/c]
@defmethod[(render-link [dest string?] [title string?] [rendered-elems list?]) any/c]
@defmethod[(render-image [src string?] [title string?] [desc string?] [raw-elems list?]) any/c]
@defmethod[(render-html [raw-content any/c]) any/c]
@defmethod[(render-footnote-reference [label string?] [defn-num string?] [ref-num string?]) any/c]
@defmethod[(render-footnote-definition [label string?] [ref-count string?] [rendered-elems list?]) any/c]

}


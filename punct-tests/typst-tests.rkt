#lang racket/base

;; Tests for the Typst renderer

(require rackunit
         punct/doc
         punct/render/typst)

;; Helper to create test documents
(define (make-doc body [footnotes '()])
  (document (hasheq) body footnotes))

;; Test: Basic paragraph
(check-equal?
 (doc->typst (make-doc '((paragraph "Hello, world!"))))
 "Hello, world!\n\n"
 "Simple paragraph")

;; Test: Heading levels
(check-equal?
 (doc->typst (make-doc '((heading [[level "1"]] "Title"))))
 "= Title\n\n"
 "H1 heading")

(check-equal?
 (doc->typst (make-doc '((heading [[level "2"]] "Subtitle"))))
 "== Subtitle\n\n"
 "H2 heading")

(check-equal?
 (doc->typst (make-doc '((heading [[level "3"]] "Section"))))
 "=== Section\n\n"
 "H3 heading")

;; Test: Bold and italic
(check-equal?
 (doc->typst (make-doc '((paragraph (bold "strong")))))
 "*strong*\n\n"
 "Bold text")

(check-equal?
 (doc->typst (make-doc '((paragraph (italic "emphasis")))))
 "_emphasis_\n\n"
 "Italic text")

;; Test: Inline code
(check-equal?
 (doc->typst (make-doc '((paragraph (code "x = 1")))))
 "`x = 1`\n\n"
 "Inline code")

;; Test: Code block
(check-equal?
 (doc->typst (make-doc '((code-block [[info "python"]] "def foo():\n    pass"))))
 "```python\ndef foo():\n    pass\n```\n\n"
 "Code block with language")

(check-equal?
 (doc->typst (make-doc '((code-block [[info ""]] "plain code"))))
 "```\nplain code\n```\n\n"
 "Code block without language")

;; Test: Links
(check-equal?
 (doc->typst (make-doc '((paragraph (link [[dest "https://example.com"]] "click here")))))
 "#link(\"https://example.com\")[click here]\n\n"
 "Link")

;; Test: Images
(check-equal?
 (doc->typst (make-doc '((paragraph (image [[src "photo.jpg"] [title ""] [desc "A photo"]])))))
 "#image(\"photo.jpg\")\n\n"
 "Image")

;; Test: Line break
(check-equal?
 (doc->typst (make-doc '((paragraph "line1" (line-break) "line2"))))
 "line1\\\nline2\n\n"
 "Line break")

;; Test: Thematic break
(check-equal?
 (doc->typst (make-doc '((thematic-break))))
 "#line(length: 100%)\n\n"
 "Thematic break / horizontal rule")

;; Test: Blockquote
(check-equal?
 (doc->typst (make-doc '((blockquote (paragraph "quoted text")))))
 "#quote(block: true)[\nquoted text\n\n]\n\n"
 "Blockquote")

;; Test: Bullet list (tight)
(check-equal?
 (doc->typst (make-doc '((itemization [[style "tight"] [start ""]]
                          (item "one")
                          (item "two")
                          (item "three")))))
 "- one\n- two\n- three\n\n\n"
 "Tight bullet list")

;; Test: Numbered list
(check-equal?
 (doc->typst (make-doc '((itemization [[style "tight"] [start "1"]]
                          (item "first")
                          (item "second")))))
 "+ first\n+ second\n\n\n"
 "Numbered list")

;; Test: Footnotes (inline)
(check-equal?
 (doc->typst (make-doc
              '((paragraph "Some text" (footnote-reference [[label "fn1"] [defn-num "1"] [ref-num "1"]])))
              '((footnote-definition [[label "fn1"] [ref-count "1"]] (paragraph "Footnote content")))))
 "Some text#footnote[Footnote content]\n\n"
 "Inline footnote")

;; Test: Multiple elements combined
(check-equal?
 (doc->typst (make-doc '((heading [[level "1"]] "Welcome")
                         (paragraph "This is " (bold "important") " text."))))
 "= Welcome\n\nThis is *important* text.\n\n"
 "Combined heading and paragraph with bold")

;; Test: Nested formatting
(check-equal?
 (doc->typst (make-doc '((paragraph (bold (italic "bold-italic"))))))
 "*_bold-italic_*\n\n"
 "Nested bold and italic")

;; Test: Loose list (with blank lines)
(check-equal?
 (doc->typst (make-doc '((itemization [[style "loose"] [start ""]]
                          (item "one")
                          (item "two")))))
 "- one\n\n- two\n\n\n\n"
 "Loose bullet list")

;; Test: Custom/unknown element uses fallback (inside a paragraph)
(check-equal?
 (doc->typst (make-doc '((paragraph "text " (custom-tag "content")))))
 "text #custom-tag(content)\n\n"
 "Custom inline tag uses default fallback")

;; Tests for special character escaping

;; Test: Hash and dollar escaping
(check-equal?
 (doc->typst (make-doc '((paragraph "Price is $10 for #items"))))
 "Price is \\$10 for \\#items\n\n"
 "Escapes $ and # in text")

;; Test: Asterisk and underscore escaping
(check-equal?
 (doc->typst (make-doc '((paragraph "Use *asterisks* and _underscores_"))))
 "Use \\*asterisks\\* and \\_underscores\\_\n\n"
 "Escapes * and _ in text")

;; Test: Brackets and at-sign escaping
(check-equal?
 (doc->typst (make-doc '((paragraph "Array[0] and @mention"))))
 "Array\\[0\\] and \\@mention\n\n"
 "Escapes [ ] and @ in text")

;; Test: Backtick escaping
(check-equal?
 (doc->typst (make-doc '((paragraph "Use `backticks` for code"))))
 "Use \\`backticks\\` for code\n\n"
 "Escapes backticks in text")

;; Test: Backslash escaping
(check-equal?
 (doc->typst (make-doc '((paragraph "Path is C:\\Users\\name"))))
 "Path is C:\\\\Users\\\\name\n\n"
 "Escapes backslashes in text")

;; Test: No escaping in code blocks
(check-equal?
 (doc->typst (make-doc '((code-block [[info ""]] "No escaping $here # @needed"))))
 "```\nNo escaping $here # @needed\n```\n\n"
 "No escaping in code blocks")

;; Test: No escaping in inline code
(check-equal?
 (doc->typst (make-doc '((paragraph (code "$var = #hash")))))
 "`$var = #hash`\n\n"
 "No escaping in inline code")

;; Test: Escaping in headings
(check-equal?
 (doc->typst (make-doc '((heading [[level "1"]] "Chapter #1: $money"))))
 "= Chapter \\#1: \\$money\n\n"
 "Escapes special chars in headings")

;; Test: Escaping in bold/italic
(check-equal?
 (doc->typst (make-doc '((paragraph (bold "cost: $100")))))
 "*cost: \\$100*\n\n"
 "Escapes special chars in bold")

(check-equal?
 (doc->typst (make-doc '((paragraph (italic "@user said #thing")))))
 "_\\@user said \\#thing_\n\n"
 "Escapes special chars in italic")

;; Test: URL escaping (quotes and backslashes)
(check-equal?
 (doc->typst (make-doc '((paragraph (link [[dest "https://example.com/path?q=\"test\""]] "link")))))
 "#link(\"https://example.com/path?q=\\\"test\\\"\")[link]\n\n"
 "Escapes quotes in URLs")

;; Test: Link text escaping
(check-equal?
 (doc->typst (make-doc '((paragraph (link [[dest "https://example.com"]] "Click $here")))))
 "#link(\"https://example.com\")[Click \\$here]\n\n"
 "Escapes special chars in link text")

;; Test: Footnote content escaping
(check-equal?
 (doc->typst (make-doc
              '((paragraph "Note" (footnote-reference [[label "fn1"] [defn-num "1"] [ref-num "1"]])))
              '((footnote-definition [[label "fn1"] [ref-count "1"]] (paragraph "Cost: $50")))))
 "Note#footnote[Cost: \\$50]\n\n"
 "Escapes special chars in footnotes")

(displayln "All Typst renderer tests passed!")

#lang racket/base

;; Tests for the syntax-coloring lexer

(require racket/list
         rackunit
         syntax-color/module-lexer
         punct/private/color-lexer)

(define (type-of a) (if (hash? a) (hash-ref a 'type) a))
(define (attrib a key) (and (hash? a) (hash-ref a key #f)))

;; Runs lexer over src from position pos with mode, checking that tokens are
;; contiguous. Each result is (text attribs backup mode-before).
(define (lex-raw src [lexer punct-color-lexer] #:from [pos 1] #:mode [mode #f])
  (define in (open-input-string src))
  (port-count-lines! in)
  (read-string (sub1 pos) in)
  (let loop ([mode mode] [pos pos] [acc '()])
    (define-values (lexeme attribs paren start end backup new-mode)
      (lexer in 0 mode))
    (check-equal? start pos (format "token starts where the last one ended, in ~s" src))
    (if (eq? attribs 'eof)
        (reverse acc)
        (loop new-mode end
              (cons (list (substring src (sub1 start) (sub1 end)) attribs backup mode)
                    acc)))))

;; Non-whitespace tokens as (text type markup)
(define (tokens src [lexer punct-color-lexer])
  (for/list ([t (in-list (lex-raw src lexer))]
             #:unless (eq? (type-of (second t)) 'white-space))
    (list (first t) (type-of (second t)) (attrib (second t) 'markup))))

;; Every token's mode must let the lexer resume at that token and reproduce
;; the rest of the token stream
(define (check-restartable src)
  (define full (lex-raw src))
  (for/fold ([pos 1]) ([t (in-list full)] [i (in-naturals)])
    (define resumed (lex-raw src #:from pos #:mode (fourth t)))
    (check-equal? (map first resumed) (map first (drop full i))
                  (format "resuming at ~a in ~s" pos src))
    (+ pos (string-length (first t)))))

(define (module-tokens src)
  (define in (open-input-string src))
  (port-count-lines! in)
  (let loop ([mode #f] [acc '()])
    (define-values (lexeme attribs paren start end backup new-mode)
      (module-lexer* in 0 mode))
    (cond
      [(eq? attribs 'eof) (reverse acc)]
      [(eq? (type-of attribs) 'white-space) (loop new-mode acc)]
      [else (loop new-mode
                  (cons (list (substring src (sub1 start) (sub1 end))
                              (type-of attribs) (attrib attribs 'markup))
                        acc))])))

;; ----------------------------------------------------------------------------

(test-case "prose is plain text"
  (check-equal? (tokens "Plain words here\n")
                '(("Plain words here" text #f))))

(test-case "metas block at the start of the document"
  (check-equal? (tokens "---\ntitle: Iceland\ndraft?: '#t\n---\n\nBody\n")
                '(("---" hash-colon-keyword meta)
                  ("title: " hash-colon-keyword meta)
                  ("Iceland" text #f)
                  ("draft?: " hash-colon-keyword meta)
                  ("'#t" text #f)
                  ("---" hash-colon-keyword meta)
                  ("Body" text #f))))

(test-case "blank lines may precede the metas block"
  (check-equal? (tokens "\n\n---\nk: v\n---\n")
                '(("---" hash-colon-keyword meta)
                  ("k: " hash-colon-keyword meta)
                  ("v" text #f)
                  ("---" hash-colon-keyword meta))))

(test-case "metas lines without a key are plain text"
  (check-equal? (tokens "---\nnot a pair\n---\n")
                '(("---" hash-colon-keyword meta)
                  ("not a pair" text #f)
                  ("---" hash-colon-keyword meta))))

(test-case "dashes after content are thematic breaks, not a metas block"
  (check-equal? (tokens "Intro\n---\nk: v\n---\n")
                '(("Intro" text #f)
                  ("---" parenthesis rule)
                  ("k: v" text #f)
                  ("---" parenthesis rule))))

(test-case "ATX headings take the whole line, inline markup included"
  (check-equal? (tokens "# Hello *world*\n\nText\n")
                '(("# Hello *world*" keyword heading)
                  ("Text" text #f))))

(test-case "heading continues across a command on the same line"
  (check-equal? (tokens "## Title •em{x} tail\n")
                '(("## Title " keyword heading)
                  ("•" parenthesis #f)
                  ("em" symbol #f)
                  ("{" parenthesis #f)
                  ("x" keyword heading)
                  ("}" parenthesis #f)
                  (" tail" keyword heading))))

(test-case "a hash without a space, or more than six, is not a heading"
  (check-equal? (tokens "#hashtag\n####### seven\n")
                '(("#hashtag" text #f)
                  ("####### seven" text #f))))

(test-case "fenced code blocks"
  (check-equal? (tokens "```racket\n(define x 1)\n```\nAfter\n")
                '(("```racket" string code)
                  ("(define x 1)" string code)
                  ("```" string code)
                  ("After" text #f))))

(test-case "a closing fence must use the same character and be at least as long"
  (check-equal? (tokens "~~~\n```\nstill\n~~~~\nout\n")
                '(("~~~" string code)
                  ("```" string code)
                  ("still" string code)
                  ("~~~~" string code)
                  ("out" text #f)))
  (check-equal? (tokens "````\n```\nstill\n````\n")
                '(("````" string code)
                  ("```" string code)
                  ("still" string code)
                  ("````" string code))))

(test-case "an unclosed fence runs to the end"
  (check-equal? (tokens "```\nforever\nand ever\n")
                '(("```" string code)
                  ("forever" string code)
                  ("and ever" string code))))

(test-case "commands inside a fence are still commands"
  (check-equal? (tokens "```\n•x{y}\n```\n")
                '(("```" string code)
                  ("•" parenthesis #f)
                  ("x" symbol #f)
                  ("{" parenthesis #f)
                  ("y" string code)
                  ("}" parenthesis #f)
                  ("```" string code))))

(test-case "inline emphasis, strong, and code spans"
  (check-equal? (tokens "Some *emph* and **strong** and `code` and _u_ here\n")
                '(("Some " text #f)
                  ("*emph*" text emphasis)
                  (" and " text #f)
                  ("**strong**" text strong)
                  (" and " text #f)
                  ("`code`" string code)
                  (" and " text #f)
                  ("_u_" text emphasis)
                  (" here" text #f))))

(test-case "underscores inside words are not emphasis; asterisks are"
  (check-equal? (tokens "snake_case_name and 2*3*4\n")
                '(("snake_case_name and 2" text #f)
                  ("*3*" text emphasis)
                  ("4" text #f))))

(test-case "unmatched delimiters are plain text"
  (check-equal? (tokens "*unclosed and __x\n")
                '(("*unclosed and __x" text #f))))

(test-case "code spans with longer backtick runs"
  (check-equal? (tokens "``a`b`` end\n")
                '(("``a`b``" string code)
                  (" end" text #f))))

(test-case "nested markup takes the outer kind"
  (check-equal? (tokens "*outer **inner** tail*\n")
                '(("*outer **inner** tail*" text emphasis))))

(test-case "links, images, and autolinks"
  (check-equal? (tokens "See [docs](https://x.y) or ![img](a.png) or <https://a.b> now\n")
                '(("See " text #f)
                  ("[docs](https://x.y)" symbol link)
                  (" or " text #f)
                  ("![img](a.png)" symbol link)
                  (" or " text #f)
                  ("<https://a.b>" symbol link)
                  (" now" text #f))))

(test-case "reference links and definitions"
  (check-equal? (tokens "Use [t][r].\n\n[r]: https://x.y \"T\"\n")
                '(("Use " text #f)
                  ("[t][r]" symbol link)
                  ("." text #f)
                  ("[r]: https://x.y \"T\"" symbol link))))

(test-case "list and quote markers precede inline content"
  (check-equal? (tokens "- item one\n1. second *x*\n> quoted\n> - nested\n")
                '(("- " parenthesis list)
                  ("item one" text #f)
                  ("1. " parenthesis list)
                  ("second " text #f)
                  ("*x*" text emphasis)
                  ("> " parenthesis quote)
                  ("quoted" text #f)
                  ("> " parenthesis quote)
                  ("- " parenthesis list)
                  ("nested" text #f))))

(test-case "thematic breaks win over list markers; a marker needs a space"
  (check-equal? (tokens "* * *\n\n---\n\n-item\n")
                '(("* * *" parenthesis rule)
                  ("---" parenthesis rule)
                  ("-item" text #f))))

(test-case "command arguments are lexed as Racket, braces as text"
  (check-equal? (tokens "•photo[\"x\" #:ext \"avif\"]{cap *em*}\n")
                '(("•" parenthesis #f)
                  ("photo" symbol #f)
                  ("[" parenthesis #f)
                  ("\"x\"" string #f)
                  ("#:ext" hash-colon-keyword #f)
                  ("\"avif\"" string #f)
                  ("]" parenthesis #f)
                  ("{" parenthesis #f)
                  ("cap " text #f)
                  ("*em*" text emphasis)
                  ("}" parenthesis #f))))

(test-case "text after the #lang line does not count as a line start"
  (check-equal? (tokens " jdcom\n---\nk: v\n---\n" )
                '((" jdcom" text #f)
                  ("---" parenthesis rule)
                  ("k: v" text #f)
                  ("---" parenthesis rule)))
  (check-equal? (drop (tokens "#lang punct jdcom\n---\nk: v\n---\n" module-lexer*) 1)
                '((" jdcom" text #f)
                  ("---" hash-colon-keyword meta)
                  ("k: " hash-colon-keyword meta)
                  ("v" text #f)
                  ("---" hash-colon-keyword meta))))

(test-case "the comment flag survives splitting"
  (define toks (lex-raw "•;{hidden *x*}\n"))
  (check-equal? (map first toks) '("•;" "{" "hidden " "*x*" "}" "\n"))
  (check-equal? (type-of (second (first toks))) 'comment)
  (for ([t (in-list (take (cdr toks) 4))])
    (check-true (attrib (second t) 'comment?) (first t)))
  (check-equal? (attrib (second (fourth toks)) 'markup) 'emphasis))

(test-case "sub-tokens report their offset in the run as backup"
  (check-equal? (map third (lex-raw "Some *emph* end\n"))
                '(0 5 11 0)))

(test-case "lexing can resume at any token with its recorded mode"
  (for-each check-restartable
            '("---\ntitle: Iceland\n---\n\n# Head *x*\n\n- a *b* `c` [d](e)\n\n```\ncode\n```\n> q\n"
              "•photo[\"x\"]{cap *em* **s**} tail\n\ntext\n")))

(test-case "the #lang reader supplies the lexer"
  (check-not-false (member '("# Hi *there*" keyword heading)
                           (module-tokens "#lang punct\n# Hi *there*\n"))))

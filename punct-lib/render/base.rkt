#lang racket/base

(require "../private/tsexp.rkt"
         "../doc.rkt"
         racket/class
         racket/match)

(provide punct-abstract-render%)

(define punct-abstract-render%
  (class object%
    (init-field doc render-fallback)
    
    (abstract render-thematic-break
              render-heading
              render-code-block
              render-html-block
              render-paragraph
              render-blockquote
              render-itemization
              render-item

              render-line-break
              render-bold
              render-italic
              render-code
              render-link
              render-image
              render-html
              render-footnote-reference
              render-footnote-definition)

    (define/public (render-document)
      (values (render-elements (document-body doc))
              (render-footnote-definitions (document-footnotes doc))))

    (define (render-elements elems)
      (for/list ([elem (in-list elems)]) (render-element elem)))

    (define (render-footnote-definitions fns)
      (for/list ([fn (in-list fns)])
        (match fn
          [`(footnote-definition [[label ,label] [ref-count ,ref-count]] . ,elems)
           (render-footnote-definition label ref-count (render-elements elems))])))

    (define (render-element elem)
      (match elem
        [(? string?) elem]
          
        ;; CommonMark block-level content
        [`(heading ((level ,lev)) . ,elems) (render-heading lev (render-elements elems))]
        [`(paragraph . ,elems) (render-paragraph (render-elements elems))]
        [`(blockquote . ,elems) (render-blockquote (render-elements elems))]
        [`(code-block [[info ,info]] . ,elems) (render-code-block info elems)]
        [`(itemization [[style ,style] [start ,start]] . ,elems) (render-itemization style start (render-elements elems))]
        [`(item . ,elems) (render-item (render-elements elems))]
        ['(thematic-break) (render-thematic-break)]
        [`(html-block ,elem) (render-html-block elem)]

        ;; CommonMark inline content
        [`(link [[dest ,dest] [title ,title]] . ,elems) (render-link dest title (render-elements elems))]
        [`(italic . ,elems) (render-italic (render-elements elems))]
        [`(bold . ,elems) (render-bold (render-elements elems))]
        [`(code . ,elems) (render-code (render-elements elems))]
        [`(image [[src ,src] [title ,title] [desc ,desc]] . ,elems) (render-image src title desc elems)]
        [`(footnote-reference [[label ,label] [defn-num ,defn-num] [ref-num ,ref-num]])
         (render-footnote-reference label defn-num ref-num)]
        ['(line-break) (render-line-break)]
        [`(html ,elem) (render-html elem)]

        ;; Other
        [(list* (? symbol? tag) (list (? attr? attrs) ...) elems) (render-fallback tag attrs (render-elements elems))]
        [(list* (? symbol? tag) elems) (render-fallback tag '() (render-elements elems))]))
    
    (super-new)))


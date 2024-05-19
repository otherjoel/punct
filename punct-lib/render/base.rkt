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
        [(tx* 'heading (level) elems) (render-heading level (render-elements elems))]
        [(tx* 'paragraph elems) (render-paragraph (render-elements elems))]
        [(tx* 'blockquote elems) (render-blockquote (render-elements elems))]
        [(tx* 'code-block (info) elems) (render-code-block info elems)]
        [(tx* 'itemization (style start) elems) (render-itemization style start (render-elements elems))]
        [(tx* 'item elems) (render-item (render-elements elems))]
        [(tx* 'thematic-break _) (render-thematic-break)]
        [(tx* 'html-block elem) (render-html-block elem)]

        ;; CommonMark inline content
        [(tx* 'link (dest title?) elems) (render-link dest title (render-elements elems))]
        [(tx* 'italic elems) (render-italic (render-elements elems))]
        [(tx* 'bold elems) (render-bold (render-elements elems))]
        [(tx* 'code elems) (render-code (render-elements elems))]
        [(tx* 'image (src title? desc?) elems) (render-image src title desc elems)]
        [(tx* 'footnote-reference (label defn-num ref-num) _)
         (render-footnote-reference label defn-num ref-num)]
        [(tx* 'line-break _) (render-line-break)]
        [(tx* 'html elem) (render-html elem)]

        ;; Other
        [(txexpr tag attrs elems) (render-fallback tag attrs (render-elements elems))]))
    
    (super-new)))


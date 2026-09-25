#lang racket/base

(require "../private/element-base.rkt"
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

    ;; Override this method in subclasses to transform raw text strings
    ;; before they are passed to element renderers (e.g., for escaping)
    (define/public (render-string s) s)

    (define (render-element elem)
      (match elem
        [(? string?) (render-string elem)]
          
        ;; CommonMark block-level content
        [(element* 'heading (level) elems) (render-heading level (render-elements elems))]
        [(element* 'paragraph elems) (render-paragraph (render-elements elems))]
        [(element* 'blockquote elems) (render-blockquote (render-elements elems))]
        [(element* 'code-block (info) elems) (render-code-block info elems)]
        [(element* 'itemization (style start) elems) (render-itemization style start (render-elements elems))]
        [(element* 'item elems) (render-item (render-elements elems))]
        [(element* 'thematic-break _) (render-thematic-break)]
        [(element* 'html-block elem) (render-html-block elem)]

        ;; CommonMark inline content
        [(element* 'link (dest title?) elems) (render-link dest title (render-elements elems))]
        [(element* 'italic elems) (render-italic (render-elements elems))]
        [(element* 'bold elems) (render-bold (render-elements elems))]
        [(element* 'code elems) (render-code elems)]  ;; raw elements, like code-block
        [(element* 'image (src title? desc?) elems) (render-image src title desc elems)]
        [(element* 'footnote-reference (label defn-num ref-num) _)
         (render-footnote-reference label defn-num ref-num)]
        [(element* 'line-break _) (render-line-break)]
        [(element* 'html elem) (render-html elem)]

        ;; Other
        [(element tag attrs elems) (render-fallback tag attrs (render-elements elems))]))
    
    (super-new)))


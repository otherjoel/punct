#lang racket/base

(require (for-syntax racket/base
                     racket/string
                     syntax/parse)
         "../private/element-base.rkt"
         "../doc.rkt"
         racket/class
         racket/match)

(provide punct-abstract-render%
         rules
         define-rules)

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


;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Rules shorthand

(begin-for-syntax
  ;; One attribute in a clause head: `id` must be present; `[id default]` need not be
  (define-syntax-class attr-spec
    #:attributes (pat)
    (pattern id:id
             #:with pat #'['id id])
    (pattern [id:id default:expr]
             #:with pat #'['id id #:default default]))

  (define-syntax-class clause-head
    #:attributes (tag-pat attrs-pat)
    #:literals (or)
    (pattern (or tag:id ...+)
             #:with tag-pat #'(or 'tag ...)
             #:with attrs-pat #'_)
    (pattern (tag:id attr:attr-spec ...)
             #:with tag-pat #''tag
             #:with attrs-pat #'(app attrs->hash (hash* attr.pat ...)))
    (pattern tag:id
             #:with tag-pat #''tag
             #:with attrs-pat #'_))

  ;; aside.note.wide → (values 'aside "note wide")
  (define (split-tag-id id-stx)
    (define parts (string-split (symbol->string (syntax-e id-stx)) "." #:trim? #f))
    (define tag (car parts))
    (define classes (cdr parts))
    (when (or (string=? tag "") (member "" classes))
      (raise-syntax-error #f "expected a tag name, optionally followed by .class names" id-stx))
    (values (string->symbol tag) (and (pair? classes) (string-join classes " ")))))

(define-syntax (rules stx)
  (syntax-parse stx
    #:literals (else)
    [(_ (tag-id:id attrs-id:id elems-id:id)
        #:default default-expr:expr
        (~and clause [(~not else) . _]) ...
        (~optional [else else-body:expr ...+]))
     (define (clause->match-clause c)
       (syntax-parse c
         [[head:clause-head (~optional (~seq #:when guard:expr)) #:as new-id:id]
          (define-values (tag class) (split-tag-id #'new-id))
          (with-syntax ([new-tag tag]
                        [attrs (if class #`'((class #,class)) #''())])
            #'[(head.tag-pat head.attrs-pat)
               (~? (~@ #:when guard))
               (default 'new-tag attrs elems-id)])]
         [[head:clause-head (~optional (~seq #:when guard:expr)) body:expr ...+]
          #'[(head.tag-pat head.attrs-pat) (~? (~@ #:when guard)) (let () body ...)]]))
     (with-syntax ([(match-clause ...) (map clause->match-clause (attribute clause))])
       #'(let ([default default-expr])
           (λ (tag-id attrs-id elems-id)
             (match* (tag-id attrs-id)
               match-clause ...
               [(_ _) (~? (let () else-body ...)
                          (default tag-id attrs-id elems-id))]))))]))

(define-syntax (define-rules stx)
  (syntax-parse stx
    [(_ (name:id tag-id:id attrs-id:id elems-id:id) clause ...)
     #'(define name (rules (tag-id attrs-id elems-id) clause ...))]))

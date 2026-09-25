#lang racket/base

(require racket/match
         rackunit
         punct/core
         punct/element
         punct/private/pack
         punct/render/plaintext)

(define (parts x) (call-with-values (λ () (element-parts x)) list))

(check-true (element? '(p)))
(check-true (element? '(p "hi")))
(check-false (element? "p"))
(check-false (element? '()))
(check-false (element? '("p" "hi")))

(check-true (attr? '(id "a")))
(check-false (attr? '(id 3)))
(check-false (attr? '(id #t)))
(check-false (attr? '(id)))
(check-false (attr? '(id "a" "b")))

(check-equal? (parts '(p)) '(p () ()))
(check-equal? (parts '(p "a" (em "b"))) '(p () ("a" (em "b"))))
(check-equal? (parts '(p ((class "x")) "a")) '(p ((class "x")) ("a")))
(check-equal? (parts '(p () "a")) '(p () ("a")))
(check-equal? (parts '(p (b "x") "y")) '(p () ((b "x") "y")))
(check-equal? (parts '(p (br))) '(p () ((br))))
(check-equal? (parts '(photo ((srcset #t) (count "3")) "c")) '(photo () (((srcset #t) (count "3")) "c")))
(check-equal? (parts '(note ((b (i "x"))))) '(note () (((b (i "x"))))))
(check-equal? (parts '(link ((dest "/a") (title "")) "text")) '(link ((dest "/a") (title "")) ("text")))
(check-equal? (parts '(image ((src "a.png") (title "") (desc "d")))) '(image ((src "a.png") (title "") (desc "d")) ()))

(check-equal? (element-tag '(p ((id "a")) "x")) 'p)
(check-equal? (element-attrs '(p ((id "a")) "x")) '((id "a")))
(check-equal? (element-attrs '(p "x")) '())
(check-equal? (element-children '(p ((id "a")) "x" (b "y"))) '("x" (b "y")))

(check-equal? (make-element 'p) '(p))
(check-equal? (make-element 'p '() '("a")) '(p "a"))
(check-equal? (make-element 'p '((id "a")) '("a")) '(p ((id "a")) "a"))
(for ([x (list '(p) '(p "a" (em "b")) '(p ((class "x")) "a") '(photo ((srcset "x"))))])
  (check-equal? (apply make-element (parts x)) x "round trip"))

(define attrs '((dest "/a") (title "T")))
(check-equal? (ref-attr attrs 'dest) "/a")
(check-equal? (ref-attr attrs 'nope) #f)
(check-equal? (ref-attr attrs 'nope "d") "d")
(check-equal? (ref-attr '() 'id) #f)

(check-equal? (set-attr attrs 'dest "/b") '((dest "/b") (title "T")) "replaces in place")
(check-equal? (set-attr attrs 'class "c") '((dest "/a") (title "T") (class "c")) "adds at the end")
(check-equal? (set-attr '() 'id "a") '((id "a")))

(check-equal? (remove-attr attrs 'title) '((dest "/a")))
(check-equal? (remove-attr '((id "a")) 'id) '())
(check-equal? (remove-attr '() 'id) '())

(define doc
  '(root (paragraph "See " (link ((dest "/a") (title "")) "A") " and "
                    (emphasis (link ((dest "/b") (title "")) "B")))
         (image ((src "c.png") (title "") (desc "C")))))

(check-equal?
 (element-map (match-lambda
                [(element 'link attrs kids)
                 (make-element 'link (set-attr attrs 'dest (string-append "https://x.com" (ref-attr attrs 'dest))) kids)]
                [x x])
              doc)
 '(root (paragraph "See " (link ((dest "https://x.com/a") (title "")) "A") " and "
                   (emphasis (link ((dest "https://x.com/b") (title "")) "B")))
        (image ((src "c.png") (title "") (desc "C")))))

(check-equal? (element-map (λ (x) (if (string? x) (string-upcase x) x)) '(p ((id "a")) "b" (em "c")))
              '(p ((id "a")) "B" (em "C"))
              "attribute values are not visited")
(check-equal? (element-map (λ (x) (if (and (element? x) (eq? (element-tag x) 'em)) "E" x))
                           '(p (em "a")))
              '(p "E"))
(check-equal? (element-map (λ (x) (if (equal? x "a") "b" x)) "a") "b")

(define (link? x) (eq? (element-tag x) 'link))
(check-equal? (element-find link? doc) '(link ((dest "/a") (title "")) "A"))
(check-equal? (element-find (λ (x) (eq? (element-tag x) 'root)) doc) doc)
(check-false (element-find (λ (x) (eq? (element-tag x) 'table)) doc))
(check-false (element-find link? "not an element"))

(check-equal? (map (λ (x) (ref-attr (element-attrs x) 'dest)) (element-find* link? doc)) '("/a" "/b"))
(check-equal? (element-find* (λ (x) (eq? (element-tag x) 'table)) doc) '())
(check-equal? (map element-tag (element-find* (λ (x) (memq (element-tag x) '(div p em))) '(div (p (em "a")) (em "b"))))
              '(div p em em)
              "document order")

(define (describe x)
  (match x
    [(element 'link (app (λ (as) (ref-attr as 'dest)) dest) kids) (list 'link dest kids)]
    [(element tag '() kids) (list tag 'no-attrs (length kids))]
    [(element tag attrs _) (list tag (map car attrs))]
    [_ 'other]))

(check-equal? (describe '(link ((dest "/a") (title "")) "A")) '(link "/a" ("A")))
(check-equal? (describe '(p "a" "b")) '(p no-attrs 2))
(check-equal? (describe '(p ((id "x") (srcset "y")))) '(p (id srcset)))
(check-equal? (describe "p") 'other)
(check-equal? (describe '()) 'other)

(define-element thing)
(check-equal? (thing #:id "a" "x") '(thing ((id "a")) "x"))
(check-equal? (thing #:id #f "x") '(thing "x"))
(define-element box #:class "wide")
(check-equal? (box #:class #f "x") '(box "x") "#f at the call site removes a default")
(check-equal? (box #:class "narrow" "x") '(box ((class "narrow")) "x"))
(check-exn #rx"attribute values must be strings" (λ () (thing #:count 3 "x")))

(check-equal? (flatpack '(thing ((id "a")) "x")) (flatpack (thing #:id "a" "x")))
(check-exn #rx"thing: attribute values must be strings.*count.*3"
           (λ () (flatpack '(thing ((id "a") (count 3)) "x"))))
(check-exn #rx"attribute values must be strings" (λ () (flatpack '(p "a" (thing ((flag #t)))))))

(define (plain . body) (doc->plaintext (document (hasheq) body '()) 72))
(check-regexp-match #rx"^ \\* c" (plain '(itemization ((style "tight") (start "")) (item "c"))))
(check-regexp-match #rx"^1\\. a" (plain '(itemization ((style "tight") (start "1")) (item "a"))))

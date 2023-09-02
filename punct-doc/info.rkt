#lang info

(define collection "punct")
(define scribblings '(("punct.scrbl")))

(define deps '("scribble-lib"
               "base"))
(define build-deps '("commonmark-doc"
                     "commonmark-lib"
                     "pollen"
                     "racket-doc"
                     "scribble-doc"
                     "punct-lib"))

(define update-implies '("punct-lib"))

(define pkg-desc "documentation part of \"punct\"")
(define license 'BlueOak-1.0.0)

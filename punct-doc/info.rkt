#lang info

(define collection "punct")
(define scribblings '(("punct.scrbl")))

(define deps '("base"))
(define build-deps '("punct-lib"))

(define update-implies '("punct-lib"))

(define pkg-desc "documentation part of \"punct\"")
(define license 'BlueOak-1.0.0)

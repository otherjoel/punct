#lang info

(define collection "punct")

(define build-deps '("scribble-lib"
                     "punct-lib"))
(define deps '("punct-lib"
               "rackunit-lib"
               "base"))
(define update-implies '("punct-lib"))

(define pkg-desc "tests part of \"punct\"")
(define license 'BlueOak-1.0.0)

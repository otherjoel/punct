#lang info

(define collection "punct")
(define version "1.4")
(define pkg-desc "implementation part of \"punct\"")
(define license 'LicenseRef-CreatorCxn-1.0)
(define install-collection "private/install.rkt")

(define deps '("at-exp-lib"
               "commonmark-lib"
               "threading-lib"
               "base"))

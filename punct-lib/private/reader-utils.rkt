#lang racket/base

; SPDX-License-Identifier: BlueOak-1.0.0
; This file is licensed under the Blue Oak Model License 1.0.0.

;; Functions used by punct’s reader to grab shorthand requires and metas

(require syntax/readerr)

(provide read-line-modpaths
         read-metas-block)

;; ~~~ Exceptions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;; Stashes a port’s position values (if given a port) or retrieves the last such
;; values (if given no arguments). Useful for error reporting.
(define save-portloc
  (let ([lnum #f]
        [col #f]
        [pos 1])
    (case-lambda
      [() (values lnum col pos)]
      [(port)
       (let-values ([(l c p) (port-next-location port)])
         (set! lnum l)
         (set! col c)
         (set! pos p))])))

;; Raise exn:fail:read using last saved port location
(define (balk! n p msg)
  (define-values (lnum col pos) (save-portloc))
  (define-values (zln zcol zpos) (port-next-location p))
  (raise-read-error msg n lnum col pos (- zpos pos)))

;; ~~~ Reader helpers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

(define (char-newline? c)
  (for/or ([newline (in-list '(#\newline #\return))])
    (equal? c newline)))

;; Returns two values without consuming any characters from the port:
;;  → The string comprising all characters occuring before \r or \n
;;  → The number of characters used in the terminating linefeed: 2 for \r\n, 1 otherwise.
(define (peek-line in [start 0])
  (define lf 10) ; \n
  (define cr 13) ; \r
  (let loop ([line-bytes '()]
             [pos start])
    (define next (peek-byte in pos))
    (cond
      [(eof-object? next) (values next 0)]
      [(equal? next lf) (values (bytes->string/utf-8 (list->bytes (reverse line-bytes))) 1)]
      [(equal? next cr)
       (values (bytes->string/utf-8 (list->bytes (reverse line-bytes)))
               (if (equal? lf (peek-byte in (add1 pos))) 2 1))]
      [else (loop (cons next line-bytes) (add1 pos))])))

;; Returns a list of all syntax objects on the port that occur before
;; the next newline/EOF. If any datum is not a valid module path, raises an
;; exn:fail:read exception.
(define (read-line-modpaths name in)
  (let loop ([vs '()] [start 0])
    (define next-char (peek-char in start))
    (cond
      [(char-newline? next-char) (reverse vs)]
      [(eof-object? next-char) (reverse vs)]
      [(char-whitespace? next-char) (loop vs (add1 start))]
      [else
       (save-portloc in)
       (define datum (read-syntax name in))
       (if (module-path? (syntax->datum datum))
           (loop (cons datum vs) 0)
           (balk! name in (format "Not a valid-module-path: ~a" datum)))])))

;; Peeks lines on port, skipping whitespace-only lines; if it finds a line
;; consisting solely of 2+ consecutive hyphens (with or without leading or
;; trailing whitespace), it consumes all lines up to the next such three-hyphen
;; line, parsing them as key-value pairs separated by ‘:’ and returning them as
;; a flat list.
(define (read-metas-block name in)
  (define block-start-found?
    (let loop ([start 0])
      (define-values (line return-len) (peek-line in start))
      (cond
        [(eof-object? line) #f]
        [(regexp-match? #px"^\\s*$" line) (loop (+ start (string-length line) return-len))]
        [(regexp-match? #px"^\\s*-{3,}\\s*$" line)
         (begin0
           #t
           (read-string (+ start (string-length line) return-len) in))] ; consume to here
        [else #f])))
  (and
   block-start-found?
   (let loop ([kvs '()])
     (save-portloc in)
     (define-values (line _retlen) (peek-line in))
     (cond
       [(eof-object? line) (begin0 kvs (read-line in 'any))]
       [(regexp-match? #px"^\\s*-{3,}\\s*$" line) (begin0 kvs (read-line in 'any))]
       [(regexp-match? #px"^\\s*$" line) (read-line in 'any) (loop kvs)] ; skip empty lines
       [else
        ; "key : value:" → '((0 . 12) (0 . 3) (6 . 12))
        (define kv (regexp-match-positions #px"^\\s*([^:]|\\S[^:]*\\S)\\s*:\\s*(\\S|.*\\S)\\s*$" line))
        (cond
          [(list? kv)
           (define k (string->symbol (substring line (caadr kv) (cdadr kv))))
           (define v (substring line (caaddr kv) (cdaddr kv)))
           (read-string (car (caddr kv)) in) ; consume to just before start of value
           (cond
             [(char=? #\' (string-ref v 0))
              (loop (cons `',k (cons (read-meta-datum name in) kvs)))]
             [else
              (read-line in 'any)
              (loop (cons `',k (cons v kvs)))])]
          [else (balk! name in "Line in metas block must be of form \"key: value\"")])]))))

;; Attempt to read a datum only up to the next newline
(define (read-meta-datum name in)
  (save-portloc in)
  (with-handlers ([exn:fail:read? (λ (e) (balk! name in (exn-message e)))])
    (read (open-input-string (read-line in 'any)))))

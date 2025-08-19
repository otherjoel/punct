#lang racket/base

(require racket/date
         racket/file)

;;================================================
;; One-time installation message:
;;   Remind users to comply with the license by emailing me to introduce
;;   themselves. Set a prefs value to prevent the message from being
;;   displayed every time `raco setup` is run.
;;

(provide installer)

(define installed-key         'punct-install-date)
(define (already-installed?)  (get-preference installed-key))
(define (save-install-date!)  (put-preferences (list installed-key)
                                               (list (date->string (current-date)))))
(define (unset-installation!) (put-preferences (list installed-key) '(#f)))

(define (installer _cols-parent _col-dir _user-specific? _avoid-install?)
  (unless (already-installed?)
    (save-install-date!)
    (displayln "    License reminder: email joel@jdueck.net to introduce yourself!")))

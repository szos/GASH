(use-modules (ice-9 format)
	     (ice-9 popen)
	     (ice-9 rdelim)
	     (ice-9 textual-ports))

;;; general niceties.

(define-macro (when cond expr . rest)
  `(if ,cond
       (begin ,expr . ,rest)
       nil))

(define-macro (bset! . to-set)
  `(begin (set! ,@to-set) ,(car to-set)))

(define-macro (display-fmt str . fmt)
  `(display (format #f ,str ,@fmt)))

(define-macro (system-fmt str . fmt)
  `(system (format #f ,str ,@fmt)))

(define (print-err text)
  (display-color 9 "ERROR:  ")
  (display text)
  (newline))

(define (with-term-color color text)
  (format #f "'\\033[38;5;~Am~A\\033[0m'" color text))

(define (open-term-color color)
  (format #f "\\033[38;5;~Am" color))

(define (close-term-color)
  (format #f "\\033[0m"))

(define *parse-color-switch-string* "#^")

(define *default-parse-color* 10)

(define *number-characters* '(#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9))

(define (get-int charbag)
  (if (< (length charbag) 3)
      (throw 'charbag-to-small
	     "in the function get-int, the charbag needs to be 3 long. "))
  (let ((one (car charbag))
	(two (cadr charbag))
	(thr (caddr charbag)))
    (if (char=? one #\^)
	7
	(cond ((and (member one *number-characters*)
		    (member two *number-characters*)
		    (member thr *number-characters*))
	       (string->number (list->string (list-head charbag 3))))
	      ((and (member one *number-characters*)
		    (member two *number-characters*))
	       (string->number (list->string (list-head charbag 2))))
	      ((member one *number-characters*)
	       (string->number (list->string (list-head charbag 1))))
	      (else
	       (throw 'no-color-number
		      "there was no color number found"))))))

(define (parse-string-for-color string-to-parse . args)
  (let ((first #t))
    (let looperino ((str-lst (string->list string-to-parse))
		    (accum '()))
      (cond ((null? str-lst)
	     ;; (print-err "exiting parse-string-for-color.")
	     (if first
		 (list->string (reverse accum))
		 (list->string (append (reverse accum)
				       (string->list (close-term-color))))))
	    ((prefix? str-lst (string->list "#^"))
	     ;; (print-err "weve hit a color prefix!")
	     (let* ((color-num (get-int (cddr str-lst)))
		    (opener (open-term-color color-num))
		    (prepend (if first
				 (begin (set! first #f)
					"")
				 (close-term-color)))
		    (text-as-list
		     (reverse (string->list (string-append prepend opener)))))
	       ;; (display "color-num:  ") (display color-num) (newline)
	       (looperino (list-tail (cddr str-lst)
				     (cond ((> color-num 99)
					    3)
					   ((and (< color-num 100)
						 (> color-num 9))
                                            2)
					   (else
                                            1)))
			  (append text-as-list accum))))
	    (else
	     (looperino (cdr str-lst) (cons (car str-lst) accum))))))
  ;; (apply format (append (list #f (loop-for-colors
  ;; 				  (string->list
  ;; 				   (string-append
  ;; 				    (open-term-color *default-parse-color*)
  ;; 				    string-to-parse))
  ;; 				  '()))
  ;; 			args))
  )

;; (define (display-color color-number string)
;;   "this is for terminal output, it prints a string in the specified 24bit color."
;;   (system-fmt "printf '\\033[38;5;~Am~A\\033[0m'" color-number string))

(define-syntax display-color
  (syntax-rules ()
    ((display-color text)
     (system-fmt "printf '~a'" (parse-string-for-color text)))
    ((display-color color-number text)
     (system-fmt "printf '\\033[38;5;~Am~A\\033[0m'" color-number text))))

(define (echof string)
  (system-fmt "printf '~a\n'" (parse-string-for-color string)))
(define (printf string)
  (system-fmt "printf '~a'" (parse-string-for-color string)))

(define-syntax echo-color
  (syntax-rules ()
    ((echo-color color item)
     (begin (display-color color item)
	    (newline)))
    ((echo-color color items ...)
     (let loop ((itm-lst '(items ...)))
       (unless (null? itm-lst)
	 (display-color color (car itm-lst))
	 (newline)
	 (loop (cdr itm-lst)))))))

(define-macro (echo-fmt-test . args)
  ;; so... args is either:
  ;; (color-number control-string formatters ...)
  ;; (control-string formatters)
  `(cond ((null? ,args)
	  (newline))
	 ((number? ,(car args))
	  (echo-color ,(car args) `(format #f ,(cadr args) ,@(cddr args))))
	 (else
	  (echo-standard (format #f ,(car args) ,@(cdr args))))))

(define-syntax echo-ex
  (syntax-rules ()
    ((echo-ex)
     (newline))
    ;; ((echo item)
    ;;  (begin (display item)
    ;; 	    (newline)))
    ((echo-ex color str ...)
     (let ((is-color? (number? color)))
       (if is-color?
	   (echo-color color str ...)
	   (let loop ((lst (append '(color) '(str ...))))
	     (unless (null? lst)
	       (display (car lst))
	       (newline)
	       (loop (cdr lst)))))))))

(define-syntax echo-fmt
  (syntax-rules ()
    ((echo-fmt str one-formatter)
     (echo (format #f str one-formatter)))
    ((echo-fmt color str formatters ...)
     (let ((is-color? (number? color)))
       (if is-color?
	   (echo-color color (format #f str formatters ...))
	   (echo (format #f color str formatters ...)))))))

(define-macro (echo thing)
  `(begin (display ,thing)
	  (newline)))

(define (print strings-list)
  (map (lamdba (el)
	 (echo el))
       strings-list))

(define-macro (first thing)
  `(car ,thing))
(define-macro (second thing)
  `(cadr ,thing))
(define-macro (third thing)
  `(caddr ,thing))
(define-macro (fourth thing)
  `(cadddr ,thing))
(define-macro (fifth thing)
  `(cadr (cdddr ,thing)))
(define-macro (sixth thing)
  `(caddr (cdddr ,thing)))
(define-macro (seventh thing)
  `(cadddr (cdddr ,thing)))
(define-macro (eighth thing)
  `(cadr (cdddr (cdddr ,thing))))
(define-macro (ninth thing)
  `(caddr (cdddr (cdddr ,thing))))
(define (last l)
  (last-pair l))

;; (define-syntax run-bash-command
;;   (syntax-rules ()
;;     ((run-bash-command command)
;;      (let ((port (open-file-output-port "~/.temp-bash")))
;;        (display command port)
;;        (newline port)
;;        (close-port port)
;;        (chmod "~/.temp-bash" #o100)
;;        (system "~/.temp-bash")
;;        (system "rm ~/.temp-bash")))))

(define (remove-all x ls)
  (if (null? ls)
      '()
      (if (eq? x (car ls))
          (remove-all x (cdr ls))
          (cons (car ls)
                (remove-all x (cdr ls))))))

(define-syntax echo-with-color
  (syntax-rules ()
    ((echo-with-color color-as-number text)
     (system* "echo" (string-append "\\xlb[38;5;" text "\\xlb[m\n")))))

(define-syntax collect-shell-command
  (syntax-rules ()
    ((collect-shell-command command as-string)
     (let* ((port (open-input-pipe command))
	    (stringer (get-string-all port)))
       (close-port port)
       stringer))
    ((collect-shell-command command as-string trim-last-newline)
     (let* ((port (open-input-pipe command))
    	    (stringer (get-string-all port))
    	    (len (string-length stringer)))
       (close-port port)
       (if (and trim-last-newline
    		(char=? #\newline (string-ref stringer (- len 1))))
    	   (substring stringer 0 (- len 1))
    	   stringer)))
    ((collect-shell-command command)
     (let ((port (open-input-pipe command)))
       (let loop ((current-read (read-line port)))
	 (if (eof-object? current-read)
	     '()
	     (cons current-read (loop (read-line port)))))))))

(define-syntax collect-shell-commands
  (syntax-rules ()
    ((collect-shell-commands commands ...)
     (map (lambda (el)
	    (if (string? el)
		(collect-shell-command el)
		(eval el)))
	  '(commands ...)))
    ((collect-shell-commands as-string commands ...)
     (map (lambda (el)
	    (collect-shell-command el as-string))
	  '(commands ...)))
    ((collect-shell-commands as-string trim-last-newline commands ...)
     (map (lambda (el)
    	    (collect-shell-command el as-string trim-last-newline))
    	  '(commands ...)))
    ))

(define-macro (run-shell-commands . commands)
  `(map (lambda (el)
	  (collect-shell-command el))
	',commands))

(define-syntax collect-multiple-shell-commands
  (syntax-rules ()
    ((collect-shell-command commands)
     (let ((commands-list
	    (map (lambda (command)
		   (collect-shell-command command))
		 commands)))
       commands-list))))

(define-syntax while
  (syntax-rules ()
    ((while condition body ...)
     (let loop ()
       (if condition
	   (begin body ...
		  (loop))
	   #f)))))

(define-syntax for
  (syntax-rules (in as accum-in from to bind)
    ((for var from x to y body ...)
     (let loop ((var x))
       (if (< y var)
	   #f
	   (begin body ...
		  (loop (+ var 1))))))
    ((for element in list bind var body ...)
     (let (var)
       (map (lambda (element)
	      body ...)
	    list)))
    ((for element in list body ...)
     (map (lambda (element)
	    body ...)
	  list))
    ((for list as element body ...)
     (map (lambda (element)
	    body ...)
	  list))
    ((for list as element accum-in var body ...)
     (let (var)
       (map (lambda (element)
	      body ...)
	    list)))))

(define-macro (for-cmd-line . body)
  "This macro is for parsing the command line of a function. while its core
purpose is to take a list of flags, and what to do when they are encountered, it 
also defines two functions, shift and peek, which are called with no arguments. 
these functions both return the car of the list of command line strings, with 
shift removing the car, and peek leaving it intact. it can be called like so:

(for-cmd-line
  ((-flag) (echo \"flag\") 
   (let ((var (shift))
         (othervar (peek)))
     (cond ((string-equal var \"option\")
            (echo \"OPTION!\")
            (echo var))
           (t
            (echo othervar)))))
  ((--other-flag) (echo \"whatever this flag does)))

the above example when called with:
$ script -flag something otherthing --other-flag 
would expand into the following:
(let ((sym (command-line)))
  (define (shift) ...)
  (define (peek) ...)
  (while (not (null? sym))
    (case (string->symbol (car sym))
      ((-flag) (shift) (echo \"flag\") 
       (let ((var (shift))
             (othervar (peek)))
         (cond ((string-equal var \"option\")
                (echo \"OPTION!\")
                (echo var))
               (t
                (echo othervar)))))
      ((--other-flag) (shift) (echo \"whatever this flag does))))) 
and after running the -flag portion (which would come first in this example) the
variable 'sym' would be equal "
  (let ((cmd-name (gensym))
	(new-body
	 (map
	  (lambda (sexp)
	    (let ((flag (car sexp))
		  (todo (cdr sexp)))
	      (cons flag (cons '(shift) todo))))
	  body)))
    `(let ((,cmd-name (command-line)))
       (define (shift)
	 (catch 'wrong-type-arg
	   (lambda ()
	     (let ((c (car ,cmd-name)))
	       (set! ,cmd-name (cdr ,cmd-name))
	       c))
	   (lambda (key . args)
	     #f)))
       (define (peek)
	 (catch 'wrong-type-arg
	   (lambda ()
	     (car ,cmd-name))
	   (lambda (key . args)
	     #f)))
       (while (not (null? ,cmd-name))
	 ;; (echo ,cmd-name)
	 (case (string->symbol (car ,cmd-name))
	   ,@new-body
	   (else
	    (shift)))))))

(define (flatten x)
  (cond ((null? x) '())
	((pair? x)
	 (append (flatten (car x)) (flatten (cdr x))))
	(else (list x))))

(define (prefix? src prefix)
  "takes two lists and checks if prefix is the prefix of src"
  (when (and (not (null? prefix)) (not (null? src)))
    (let loop ((source src)
	       (pfix prefix))
      (cond ((null? pfix)
	 #t)
	((null? source)
	 #f)
	((equal? (car source) (car pfix))
	 (loop (cdr source) (cdr pfix)))
	(else
	 #f)))))

(define (append-reverse rev-head tail)
  (append (reverse rev-head) tail))

(define (replace-substring string to-replace replace-with)
  "send in 3 strings, or, 3 lists of characters"
  (let ((haystack (if (string? string) (string->list string) string))
	(needle (if (string? to-replace) (string->list to-replace) to-replace))
	(replacement (if (string? replace-with) (string->list replace-with)
			 replace-with))
	(needle-len (if (string? to-replace)
			(string-length to-replace)
			(length to-replace))))
    (let loop ((haystack haystack) (acc '()))
      (cond ((null? haystack)
	     (list->string (reverse acc)))
	    ((prefix? haystack needle)
	     (loop (list-tail haystack needle-len)
		   (append-reverse replacement acc)))
	    (else
	     (loop (cdr haystack) (cons (car haystack) acc)))))))

;; (define (string-splitter string to-split)
;;   (let ((haystack (string->list string))
;; 	(needle (string->list to-split))
;; 	(needle-len (string-length to-replace)))
;;     (let loop ((haystack haystack) (accum '()) (grand '())) ;store total in grand
;;       (cond ((null? haystack)
;; 	     grand)
;; 	    ((prefix? haystack needle)
;; 	     (loop '() (cons (list->string (reverse accum)))))
;; 	    (else
;; 	     (loop (cdr haystack) (cons (car haystack) accum) grand))))))

;; (define (directory? path)
;;   (with-throw-handler #t
;;     (lambda () (equal? 'directory (stat:type (stat path))))
;;     (lambda (key . args)
;;       #f)))

(define (join-strings-with string-list string)
  "takes a list of strings, and runs string-append on it after mixing with string
strings, so passing \"hi\" \"there\" would result in string append being passed
\"hi\" \" \" \"there\". "
  (let loop ((strings-list string-list)
	     (accum '()))
    (if (null? strings-list)
	(let ((appender ""))
	  (map (lambda (el)
		 (set! appender (string-append appender el)))
	       (reverse (cdr accum)))
	  appender)
	(loop (cdr strings-list) (cons string
				       (cons (car strings-list) accum))))))

(define (join-strings string-list string)
  (join-strings-with string-list string))

(define (char->string char)
  (list->string (list char)))

(define (do-hello)
  (display-color 2 "Hello, World!\n"))
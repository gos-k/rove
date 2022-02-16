(in-package #:cl-user)
(defpackage #:rove/suite
  (:nicknames #:rove/core/suite)
  (:use #:cl
        #:rove/core/assertion
        #:rove/core/result
        #:rove/core/test
        #:rove/core/stats)
  (:import-from #:rove/core/suite/package
                #:get-test
                #:remove-test
                #:system-suites
                #:suite-name
                #:run-suite
                #:package-suite
                #:all-suites
                #:find-suite)
  (:import-from #:rove/core/suite/file
                #:system-packages)
  (:export #:run-system-tests
           #:run-suite
           #:all-suites
           #:find-suite
           #:*last-suite-report*
           #:*rove-standard-output*
           #:*rove-error-output*
           #:get-test
           #:remove-test))
(in-package #:rove/core/suite)

(defvar *last-suite-report* nil)

(defparameter *rove-standard-output* nil)
(defparameter *rove-error-output* nil)

(defun run-system-tests (system-designator)
  (let ((system (asdf:find-system system-designator)))
    (let ((*stats* (or *stats*
                       (make-instance 'stats)))
          (*standard-output* (or *rove-standard-output*
                                 *standard-output*))
          (*error-output* (or *rove-error-output*
                              *error-output*)))

      #+quicklisp (ql:quickload (asdf:component-name system) :silent t)
      #-quicklisp (asdf:load-system (asdf:component-name system))

      (system-tests-begin *stats* system)
      (with-context (context)
        (typecase system
          (asdf:package-inferred-system
            (let* ((package-name (string-upcase (asdf:component-name system)))
                   (package (find-package package-name)))
              (unless package
                (setf package (find-package package-name)))
              ;; Loading dependencies beforehand
              (let ((pkgs (system-packages system)))
                (dolist (package pkgs)
                  (let ((suite (package-suite package)))
                    (when suite
                      (run-suite suite)))))

              (when package
                (let ((suite (package-suite package)))
                  (when suite
                    (run-suite suite))))))
          (otherwise
            (dolist (suite (system-suites system))
              (run-suite suite)))))
      (system-tests-finish *stats* system)
      (summarize *stats*)

      (let ((test (if (passedp *stats*)
                      (first (passed-tests *stats*))
                      (first (failed-tests *stats*)))))
        (let ((passed (passed-tests test))
              (failed (failed-tests test)))

          (setf *last-suite-report*
                (list (= 0 (length failed))
                      passed
                      failed))
          (apply #'values *last-suite-report*))))))

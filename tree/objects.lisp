;; objects.lisp

(in-package #:libxml2.tree)

(defclass libxml2-cffi-object-wrapper ()
  ((pointer :initarg :pointer :reader pointer)))

(defgeneric wrapper-slot-value (obj slot))
(defgeneric set-wrapper-slot-value (obj slot value))

(defgeneric release/impl (obj))
(defgeneric copy (obj))
(defgeneric (setf wrapper-slot-value) (value obj slot))


(defmethod pointer ((obj (eql nil)))
  (null-pointer))

(defmacro defwrapper (wrapper-name cffi-type)
  `(progn
     (defclass ,wrapper-name (libxml2-cffi-object-wrapper) ())
     (defmethod wrapper-slot-value ((obj ,wrapper-name) slot)
       (cffi:foreign-slot-value (pointer obj) (quote ,cffi-type) slot))
     (defmethod (setf wrapper-slot-value) (value (obj ,wrapper-name) slot)
       (setf (cffi:foreign-slot-value (pointer obj) (quote ,cffi-type) slot) value))))


(defmacro with-libxml2-object ((var value) &rest body)
  `(unwind-protect
        (let ((,var ,value))
          ,@body)
     (if ,value (release ,value))))

(defun release (obj)
  (release/impl obj)
  (setf (slot-value obj 'pointer) nil))

(gp:defcleanup libxml2-cffi-object-wrapper #'release)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; node
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defwrapper node %xmlNode)

(defmethod release/impl ((node node))
  (%xmlFreeNode (pointer node)))

(defmethod copy ((node node))
  (make-instance 'node
                 :pointer (%xmlCopyNode (pointer node) 1)))

(defun wrapper-slot-node (node slot)
  (wrapper-slot-wrapper node slot 'node))

(defun make-element (name &optional href prefix)
  (let ((%node (with-foreign-string (%name name)
                 (%xmlNewNode (null-pointer) 
                              %name))))
    (if href
        (setf (foreign-slot-value %node
                                  '%xmlNode
                                  '%ns)
              (gp:with-garbage-pool ()
                (%xmlNewNs %node
                           (gp:cleanup-register (foreign-string-alloc href) #'foreign-string-free)
                           (if prefix
                               (gp:cleanup-register (foreign-string-alloc prefix)  #'foreign-string-free)
                               (null-pointer))))))
    (make-instance 'node
                   :pointer %node)))
                
                
(defun make-text (data)
  (make-instance 'node
                 :pointer (with-foreign-string (%data data)
                            (%xmlNewText %data))))

(defun make-comment (data)
  (make-instance 'node
                 :pointer (with-foreign-string (%data data)
                            (%xmlNewComment %data))))

(defun make-process-instruction (name content)
  (make-instance 'node
                 :pointer (with-foreign-strings ((%name name) (%content content))
                            (%xmlNewPI %name %content))))

(defmacro def-node-p (name node-type)
  `(defun ,name (node &key throw-error)
     (if (eql (node-type node) ,node-type)
         t
         (if throw-error
             (error (format nil "node is not ~A" ,node-type))))))

(def-node-p element-p :xml-element-node)
(def-node-p attribute-p :xml-attribute-node)
(def-node-p text-p :xml-element-text)
(def-node-p comment-p :xml-comment-node)
(def-node-p process-instruction-p :xml-pi-node)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; attribute
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defwrapper attribute %xmlAttr)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; namespace
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defwrapper ns %xmlNs)

(defun generate-ns-prefix (element)
  (iter (for i from 1)
        (for prefix = (format nil "ns_~A" i))
        (finding prefix such-that (null-pointer-p (with-foreign-string (%prefix prefix)
                                                    (%xmlSearchNs (pointer (document element))
                                                                  (pointer element)
                                                                  %prefix))))))

(defun make-ns (element href &optional prefix)
  (make-instance 'ns
                 :pointer (with-foreign-strings ((%href href) (%prefix (or prefix (generate-ns-prefix element))))
                            (%xmlNewNs (pointer element)
                                       %href
                                       %prefix))))


(defun search-ns-by-href (element href)
  (let ((%ns (with-foreign-string (%href href)
               (%xmlSearchNsByHref (pointer (document element))
                                   (pointer element)
                                   %href))))
    (unless (null-pointer-p %ns)
      (make-instance 'ns :pointer %ns))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun make-libxml2-cffi-object-wrapper/impl (%ptr wrapper-type)
  (unless (null-pointer-p %ptr)
    (make-instance wrapper-type :pointer %ptr)))

(defun wrapper-slot-wrapper (obj slot wrapper-type)
  (make-libxml2-cffi-object-wrapper/impl (wrapper-slot-value obj slot) wrapper-type))

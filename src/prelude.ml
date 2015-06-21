(*
 *
 * For printing the smt prelude for each cu.
 *
 *)

open Printf


let addr_type aw = "(_ BitVec " ^ (string_of_int aw) ^ ")"

let byte_type = "(_ BitVec 8)"

let i64_type = "(_ BitVec 64)"

let i32_type = "(_ BitVec 32)"

let i16_type = "(_ BitVec 16)"

let mem_type aw = "(Array " ^ (addr_type  aw)^ " " ^ byte_type ^")"

let zero_address aw = "(_ bv0 " ^ (string_of_int aw) ^ ")"

let types = "
(define-sort I8 () (_ BitVec 8))
(define-sort I16 () (_ BitVec 16))
(define-sort I32 () (_ BitVec 32))
(define-sort I64 () (_ BitVec 64))
(define-sort I128 () (_ BitVec 128))
"

let constants aw = 
  let b = Buffer.create 100 in
    bprintf b 
"
;;
;;constants
;;
(define-fun zero  () Address (_ bv0 %d))
(define-fun one   () Address (_ bv1 %d))
(define-fun two   () Address (_ bv2 %d))
(define-fun three () Address (_ bv3 %d))
(define-fun four  () Address (_ bv4 %d))
(define-fun five  () Address (_ bv5 %d))
(define-fun six   () Address (_ bv6 %d))
(define-fun seven () Address (_ bv7 %d))
(define-fun eight () Address (_ bv8 %d))
" aw aw aw aw aw aw aw aw aw;
    Buffer.contents b

let writes = "
;;
;; Write a little endian 1 bit value (8 bit aligned) at address x in mem
;;
(define-fun write1 ((mem Mem) (x Address) (v Bool)) Mem
  (store mem x (ite v #x01 #x00)))

;;
;; Write a little endian 8bit value at address x in mem
;;
(define-fun write8 ((mem Mem) (x Address) (v I8)) Mem
  (store mem x v))

;;
;; Write a little endian 16bit value at address x in mem
;;
(define-fun write16 ((mem Mem) (x Address) (v I16)) Mem
  (let ((b0 ((_ extract 7 0) v))
	(b1 ((_ extract 15 8) v)))
    (store (store mem x b0) (bvadd x one) b1)))

;;
;; Write a little endian 32bit value at address x in mem
;;
(define-fun write32 ((mem Mem) (x Address) (v I32)) Mem
  (let ((b0 ((_ extract 7 0) v))
	(b1 ((_ extract 15 8) v))
	(b2 ((_ extract 23 16) v))
	(b3 ((_ extract 31 24) v)))
    (store (store (store (store mem x b0) (bvadd x one) b1) (bvadd x two) b2) (bvadd x three) b3)))

;;
;; Write a little endian 64bit value at address x in mem
;;
(define-fun write64 ((mem Mem) (x Address) (v I64)) Mem
  (let ((b0 ((_ extract 31 0) v))
	(b1 ((_ extract 63 32) v)))
    (write32 (write32 mem x b0) (bvadd x four) b1)))

;;
;; Write a little endian 128bit value at address x in mem
;;
(define-fun write128 ((mem Mem) (x Address) (v I128)) Mem
  (let ((b0 ((_ extract 63 0) v))
	(b1 ((_ extract 127 64) v)))
    (write64 (write64 mem x b0) (bvadd x eight) b1)))
"


let reads = "
;;
;; Read a little endian 1 bit value (8 bit aligned) at address x in mem
;; - returns a Boolean: true if what's stored at address x is non-zero
;;
(define-fun read1 ((mem Mem) (x Address)) Bool
   (not (= (select mem x) #x00)))

;;
;; Read a little endian 8bit value at address x in mem
;;
(define-fun read8 ((mem Mem) (x Address)) I8
  (select mem x))

;;
;; Read a little endian 16bit value at address x in mem
;;
(define-fun read16 ((mem Mem) (x Address)) I16
  (let ((b0 (select mem x))
	(b1 (select mem (bvadd x one))))
    (concat b1 b0))) 

;;
;; Read a little endian 32bit value at address x in mem
;;
(define-fun read32 ((mem Mem) (x Address)) I32
  (let ((b0 (select mem x))
	(b1 (select mem (bvadd x one)))
	(b2 (select mem (bvadd x two)))
	(b3 (select mem (bvadd x three))))
    (concat b3 (concat b2 (concat b1 b0)))))

;;
;; Read a little endian 64bit value at address x in mem
;;
(define-fun read64 ((mem Mem) (x Address)) I64
  (let ((b0 (read32 mem x))
        (b1 (read32 mem (bvadd x four))))
    (concat b1 b0)))

;;
;; Read a little endian 128bit value at address x in mem
;;
(define-fun read128 ((mem Mem) (x Address)) I128
  (let ((b0 (read64 mem x))
        (b1 (read64 mem (bvadd x eight))))
    (concat b1 b0)))
"


(*
 * For each base function: bvadd, bvmul, etc.
 * we have a variant that operates element-wise on vectors.
 * In SMT2, we must define a special version for each
 * vector size and element type.
 *)

let vector_type b len width =
  bprintf b
    "
;;
;; Vectors of (2^%d) int%d elements
;;
(define-sort vector_%d_%d () (Array (_ BitVec %d) (_ BitVec %d)))

(declare-fun vundef_%d_%d () vector_%d_%d)

"
    len width len width len width len width len width 
   

let vutils b w =
  bprintf b
    "
;;
;; Vectors of (2^1) i.e. two int%d elements
;;
(define-fun vmake_1_%d ((x0 (_ BitVec %d)) (x1 (_ BitVec %d))) vector_1_%d
   (store (store vundef_1_%d #b0 x0) #b1 x1))

;;
;; Vectors of (2^2) i.e. four int%d elements
;;
(define-fun vmake_2_%d 
  ((x0 (_ BitVec %d)) (x1 (_ BitVec %d)) (x2 (_ BitVec %d)) (x3 (_ BitVec %d))) vector_2_%d
   (store (store (store (store vundef_2_%d #b00 x0) #b01 x1) #b10 x2) #b11 x3))

;; zero vectors with int%d elements

 (define-fun vzero_1_%d () vector_1_%d (vmake_1_%d (_ bv0 %d) (_ bv0 %d)))

 (define-fun vzero_2_%d () vector_2_%d (vmake_2_%d (_ bv0 %d) (_ bv0 %d) (_ bv0 %d) (_ bv0 %d)))
 
"
    w w w w  w w w w  w w w w  w w w w  w w w w   w w w w  w w w   
    
let vector_casts = "


;; conversion to and from (Bitvector 64)
;; this assumes little endian representation
(define-fun cast_vector_1_32_to_bits ((x vector_1_32)) (_ BitVec 64)
   (concat (select x #b1) (select x #b0)))

(define-fun cast_bits_to_vector_1_32 ((w (_ BitVec 64))) vector_1_32
   (let ((z0 ((_ extract 31 0) w))
         (z1 ((_ extract 63 32) w)))
      (vmake_1_32 z0 z1)))

\n"

let binops = [
  "bvadd";
  "bvsub";
  "bvmul";
  "bvshl";
  "bvsdiv";
  "bvudiv";
  "bvlshr";
  "bvashr";
  "bvurem";
  "bvsrem";
  "bvand";
  "bvor";
  "bvxor"]

let vector_widths =  [1; 4; 8; 32; 64]

let bpr_op_1_32 b binop = 
  bprintf b 
    "
(define-fun v%s_1_32 ((x vector_1_32) (y vector_1_32)) vector_1_32
   (let ((z0 (%s (select x #b0) (select y #b0)))
         (z1 (%s (select x #b1) (select y #b1))))
      (vmake_1_32 z0 z1)))
"
    binop binop binop

let bpr_op_2_32 b binop = 
  bprintf b 
    "
 (define-fun v%s_2_32 ((x vector_2_32) (y vector_2_32)) vector_2_32
   (let ((z0 (%s (select x #b00) (select y #b00)))
         (z1 (%s (select x #b01) (select y #b01)))
         (z2 (%s (select x #b10) (select y #b10)))
         (z3 (%s (select x #b11) (select y #b11))))
      (vmake_2_32 z0 z1 z2 z3)))
\n"
     binop binop binop binop binop
   
   
   
(*
 * Prelude: a bunch of definitions to abbreviate the conversion.
 *)
let print_prelude b aw = 
  bprintf b "(set-logic QF_ABV)\n";
  bprintf b "(define-sort Address () %s)\n" (addr_type aw);
  bprintf b "(define-sort Byte () %s)\n" byte_type;
  bprintf b "(define-sort Mem () (Array Address Byte))\n";
  bprintf b "%s\n" types;
  bprintf b "%s\n" (constants aw);
  bprintf b "%s\n" writes;
  bprintf b "%s\n" reads;
  List.iter (fun width ->  (vector_type b 1 width)) vector_widths;
  List.iter (fun width ->  (vector_type b 2 width)) vector_widths;
  List.iter (fun w ->  (vutils b w)) vector_widths;
  List.iter (fun binop ->  (bpr_op_1_32 b binop)) binops;
  List.iter (fun binop ->  (bpr_op_2_32 b binop)) binops;
  bprintf b "%s\n" vector_casts;

  bprintf b "\n;; end of prelude\n\n\n";
  ()

    

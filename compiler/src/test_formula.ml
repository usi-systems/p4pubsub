open Ast
open Formula
open Dnf

let test_to_nnf () =
   let (a, b, c) = (Var(Ident("a")), Var(Ident("b")), Var(Ident("c"))) in
   let t1 = Not(Or(And(a, b), Or(a, b))) in
   let t2 = Or(And(a, b), Or(a, b)) in
   assert ((to_nnf a) = a);
   assert ((to_nnf (Not(Not(a))) ) = a);
   assert ((to_nnf (Not(a))) = Not(a));
   assert ((to_nnf t1) = And(Or(Not(a), Not(b)), And(Not(a), Not(b))));
   assert ((to_nnf t2) = Or(And(a, b), Or(a, b)))

let test_conj () =
   let (a, b, c, d) = (Var(Ident("a")), Var(Ident("b")), Var(Ident("c")), Var(Ident("d"))) in
   let t1 = And(a, And(b, c)) in
   let t2 = And(And(a, b), And(And(b, c), c)) in
   assert (conj_contains t1 a);
   assert (conj_contains t1 b);
   assert (conj_contains t1 c);
   assert (not (conj_contains t1 d));
   assert (conj_contains t2 a);
   assert (not (conj_contains t2 d))

let test_canonicalization () =
   let (a, b, c, d) = (Var(Ident("a")), Var(Ident("b")), Var(Ident("c")), Var(Ident("d"))) in
   let d1 = Or(And(And(c, a), b), Empty) in
   let d2 = And(And(c, a), b) in
   let d3 = Or(And(And(c, a), b), And(a, b)) in
   let d4 = Or(And(And(And(a, d), c), b), a) in
   assert (dnf_canonicalize d1 = And(a, And(b, c)));
   assert (dnf_canonicalize d2 = And(a, And(b, c)));
   assert (dnf_canonicalize d3 = Or(And(a, b), And(a, And(b, c))));
   assert (dnf_canonicalize d4 = Or(a, And(a, And(b, And(c, d)))))

let test_to_dnf () =
   let (x, y, z) = (Var(Ident("x")), Var(Ident("y")), Var(Ident("z"))) in
   let t =
      And(Or(x, Or(y, z)), And(Or(x, Or(Not(y), Not(z))), And(Or(y, Or(Not(x), Not(z))), Or(z, Or(Not(x), Not(y))))))
   in
   let t_dnf = 
      Or(And(x, And(y, z)), Or(And(x, And(Not(y), Not(z))), Or(And(Not(x), And(y, Not(z))), And(Not(x), And(Not(y), z)))))
   in
   assert (to_dnf t = t_dnf)

let test_partial_eval1 () =
   let (x, y, z) = (Var(Ident("x")), Var(Ident("y")), Var(Ident("z"))) in
   let t1 = And(x, And(y, z)) in
   let r1 = partial_eval_conj (Residual t1) x True in
   let r2 = partial_eval_conj r1 y True in
   let r3 = partial_eval_conj r2 z True in
   assert (r1 = (Residual(And(y, z))));
   assert (r2 = (Residual(z)));
   assert (r3 = True)

let test_partial_eval2 () =
   let (x, y, z) = (Var(Ident("x")), Var(Ident("y")), Var(Ident("z"))) in
   let q = Var(Ident("q is not in formula")) in
   let t1 = And(x, And(y, z)) in
   let r1 = partial_eval_conj (Residual t1) x False in
   let r2 = partial_eval_conj (Residual t1) y False in
   let r3 = partial_eval_conj (Residual t1) z False in
   let r4 = partial_eval_conj (Residual t1) q True in
   assert (r1 = False);
   assert (r2 = False);
   assert (r3 = False);
   assert (r4 = (Residual t1))

let test_partial_eval3 () =
   let (x, y, z) = (Var(Ident("x")), Var(Ident("y")), Var(Ident("z"))) in
   let t1 = And(x, And(y, z)) in
   let r1 = partial_eval_conj (Residual t1) z True in
   let r2 = partial_eval_conj r1 x True in
   let r3 = partial_eval_conj r2 y True in
   assert (r1 = (Residual(And(x, y))));
   assert (r2 = (Residual(y)));
   assert (r3 = True)

let test_all_partial_eval () =
   test_partial_eval1 ();
   test_partial_eval2 ();
   test_partial_eval3 ()

let test_all () =
   test_to_nnf ();
   test_conj ();
   test_canonicalization ();
   test_to_dnf ();
   test_all_partial_eval ();
   print_endline "DNF tests passed"
;;

test_all ()

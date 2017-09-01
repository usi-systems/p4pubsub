open Dnf

let test_to_nnf () =
   let (a, b, c) = (Var("a"), Var("b"), Var("c")) in
   let t1 = Not(Or(And(a, b), Or(a, b))) in
   let t2 = Or(And(a, b), Or(a, b)) in
   assert ((to_nnf a) = a);
   assert ((to_nnf (Not(Not(a))) ) = a);
   assert ((to_nnf (Not(a))) = Not(a));
   assert ((to_nnf t1) = And(Or(Not(a), Not(b)), And(Not(a), Not(b))));
   assert ((to_nnf t2) = Or(And(a, b), Or(a, b)))

let test_conj () =
   let (a, b, c, d) = (Var("a"), Var("b"), Var("c"), Var("d")) in
   let t1 = And(a, And(b, c)) in
   let t2 = And(And(a, b), And(And(b, c), c)) in
   assert (conj_contains t1 a);
   assert (conj_contains t1 b);
   assert (conj_contains t1 c);
   assert (not (conj_contains t1 d));
   assert (conj_contains t2 a);
   assert (not (conj_contains t2 d))

let test_all () =
   test_to_nnf ();
   test_conj ();
   print_endline "DNF tests passed"
;;

test_all ()

open Ast
open Formula
open Dnf

let test_to_nnf () =
   let (a, b, c) = (Atom(Ident("a")), Atom(Ident("b")), Atom(Ident("c"))) in
   let t1 = Not(Or(And(a, b), Or(a, b))) in
   let t2 = Or(And(a, b), Or(a, b)) in
   assert ((to_nnf a) = a);
   assert ((to_nnf (Not(Not(a))) ) = a);
   assert ((to_nnf (Not(a))) = Not(a));
   assert ((to_nnf t1) = And(Or(Not(a), Not(b)), And(Not(a), Not(b))));
   assert ((to_nnf t2) = Or(And(a, b), Or(a, b)))

let test_conj () =
   let (a, b, c, d) = (Atom(Ident("a")), Atom(Ident("b")), Atom(Ident("c")), Atom(Ident("d"))) in
   let t1 = And(a, And(b, c)) in
   let t2 = And(And(a, b), And(And(b, c), c)) in
   assert (conj_contains t1 a);
   assert (conj_contains t1 b);
   assert (conj_contains t1 c);
   assert (not (conj_contains t1 d));
   assert (conj_contains t2 a);
   assert (not (conj_contains t2 d))

let test_canonicalization () =
   let (a, b, c, d) = (Atom(Ident("a")), Atom(Ident("b")), Atom(Ident("c")), Atom(Ident("d"))) in
   let d1 = Or(And(And(c, a), b), Empty) in
   let d2 = And(And(c, a), b) in
   let d3 = Or(And(And(c, a), b), And(a, b)) in
   let d4 = Or(And(And(And(a, d), c), b), a) in
   assert (dnf_canonicalize d1 = And(a, And(b, c)));
   assert (dnf_canonicalize d2 = And(a, And(b, c)));
   assert (dnf_canonicalize d3 = Or(And(a, b), And(a, And(b, c))));
   assert (dnf_canonicalize d4 = Or(a, And(a, And(b, And(c, d)))))

let test_to_dnf () =
   let (x, y, z) = (Atom(Ident("x")), Atom(Ident("y")), Atom(Ident("z"))) in
   let t =
      And(Or(x, Or(y, z)), And(Or(x, Or(Not(y), Not(z))), And(Or(y, Or(Not(x), Not(z))), Or(z, Or(Not(x), Not(y))))))
   in
   let t_dnf = 
      Or(And(x, And(y, z)), Or(And(x, And(Not(y), Not(z))), Or(And(Not(x), And(y, Not(z))), And(Not(x), And(Not(y), z)))))
   in
   assert (to_dnf t = t_dnf)


let test_all () =
   test_to_nnf ();
   test_conj ();
   test_canonicalization ();
   test_to_dnf ();
   print_endline "DNF tests passed"
;;

test_all ()

open Ast
open Pretty

type atom = expr

type formula =
   | Empty
   | Atom of atom
   | Not of formula
   | And of formula * formula
   | Or of formula * formula

let atom_to_string e = Format.asprintf "%a" format_expr e

let is_exp_subset sub sup = match (sub, sup) with
   | (Gt(a, Number(x)), Gt(b, Number(y))) when a=b -> x>=y
   | (Lt(a, Number(x)), Lt(b, Number(y))) when a=b -> x<=y
   | (Eq(a, Number(x)), Gt(b, Number(y))) when a=b -> x>y
   | (Eq(a, Number(x)), Lt(b, Number(y))) when a=b -> x<y
   | _ -> false

let is_exp_disjoint e1 e2 = match (e1, e2) with
   | (Eq(a, x), Eq(b, y)) when a=b -> x!=y
   | (Gt(a, Number(x)), Eq(b, Number(y))) when a=b -> y<=x
   | (Eq(b, Number(y)), Gt(a, Number(x))) when a=b -> y<=x
   | (Lt(a, Number(x)), Eq(b, Number(y))) when a=b -> y>=x
   | (Eq(b, Number(y)), Lt(a, Number(x))) when a=b -> y>=x
   | (Lt(a, Number(x)), Gt(b, Number(y))) when a=b -> x<=y
   | (Gt(b, Number(y)), Lt(a, Number(x))) when a=b -> x<=y
   | _ -> false


(* TODO: does this sort on expr strength? e.g. "x>10" > "x>5" *)
let cmp_atoms a b = compare (atom_to_string a) (atom_to_string b)

let rec formula_to_string t =
   let rec and_to_string = function
      | And(p, q) -> Printf.sprintf "%s ∧ %s" (and_to_string p) (and_to_string q)
      | p -> formula_to_string p
   in
   let rec or_to_string = function
      | Or(p, q) -> Printf.sprintf "%s ∨ %s" (or_to_string p) (or_to_string q)
      | p -> formula_to_string p
   in
   match t with 
   | Empty -> "[Empty]"
   | Atom(a) -> atom_to_string a
   | And(_, _) as p -> Printf.sprintf "(%s)" (and_to_string p)
   | Or(_,_) as p-> Printf.sprintf "(%s)" (or_to_string p)
   | Not(a) -> Printf.sprintf "¬%s" (formula_to_string a)

let print_form t = print_endline (formula_to_string t)

let rec fold_atoms f acc t = match t with
   | Empty -> acc
   | Atom(a) -> f acc a
   | Not(x) -> fold_atoms f acc x
   | Or(x, y) | And(x, y) -> fold_atoms f (fold_atoms f acc y) x

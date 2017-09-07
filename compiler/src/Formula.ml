open Ast
open Pretty

type variable = expr

type formula =
   | Empty
   | Var of variable
   | Not of formula
   | And of formula * formula
   | Or of formula * formula

let var_to_string e = Format.asprintf "%a" format_expr e

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


(* TODO: sort on expr strength. e.g. "x>10" < "x>100" *)
let cmp_vars a b = compare (var_to_string a) (var_to_string b)

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
   | Var(a) -> var_to_string a
   | And(_, _) as p -> Printf.sprintf "(%s)" (and_to_string p)
   | Or(_,_) as p-> Printf.sprintf "(%s)" (or_to_string p)
   | Not(a) -> Printf.sprintf "¬%s" (formula_to_string a)

let print_form t = print_endline (formula_to_string t)

let rec fold_vars f acc t = match t with
   | Empty -> acc
   | Var(a) -> f acc a
   | Not(x) -> fold_vars f acc x
   | Or(x, y) | And(x, y) -> fold_vars f (fold_vars f acc y) x

let rec formula_of_query q = match q with
   | Ast.And(a, b) -> And(formula_of_query a, formula_of_query b)
   | Ast.Not(a) -> Not(formula_of_query a)
   | Ast.Or(a, b) -> Or(formula_of_query a, formula_of_query b)
   | Eq(Ident _, (Number _ | Ident _)) as p -> Var(p)
   | Lt(Ident _, Number _) as p -> Var(p)
   | Gt(Ident _, Number _) as p -> Var(p)
   | _ -> raise (Failure "Query not supported")

type evaled_formula =
   | False
   | True
   | Residual of formula

let rec partial_eval_conj resid_conj var value = match (resid_conj, var) with
   | ((True|False) as x, _) -> x
   | (Residual(Var x), Var y) when x=y -> value
   | (Residual(Not(Var x)), Var y) when x=y -> if value=True then False else True
   | ((Residual(Var _)) as r, _) | ((Residual(Not(Var _))) as r, _) -> r
   | (Residual(And(a, b)), _) ->
         (match (partial_eval_conj (Residual a) var value,
                 partial_eval_conj (Residual b) var value) with
         | (True, True) -> True
         | (False, _) | (_, False) -> False
         | (True, r) | (r, True) -> r
         | (Residual t1, Residual t2) -> Residual(And(t1, t2))
         )
   | ((Residual _) as r, _) -> partial_eval_conj r var value

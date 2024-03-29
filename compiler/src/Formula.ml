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
   | (Gt(a, NumberLit(x)), Gt(b, NumberLit(y))) when a=b -> x>=y
   | (Lt(a, NumberLit(x)), Lt(b, NumberLit(y))) when a=b -> x<=y
   | (Eq(a, NumberLit(x)), Gt(b, NumberLit(y))) when a=b -> x>y
   | (Eq(a, NumberLit(x)), Lt(b, NumberLit(y))) when a=b -> x<y
   | _ -> false

let is_exp_disjoint e1 e2 = match (e1, e2) with
   | (Eq(a, x), Eq(b, y)) when a=b -> x<>y
   | (Gt(a, NumberLit(x)), Eq(b, NumberLit(y))) when a=b -> y<=x
   | (Eq(b, NumberLit(y)), Gt(a, NumberLit(x))) when a=b -> y<=x
   | (Lt(a, NumberLit(x)), Eq(b, NumberLit(y))) when a=b -> y>=x
   | (Eq(b, NumberLit(y)), Lt(a, NumberLit(x))) when a=b -> y>=x
   | (Lt(a, NumberLit(x)), Gt(b, NumberLit(y))) when a=b -> x<=y
   | (Gt(b, NumberLit(y)), Lt(a, NumberLit(x))) when a=b -> x<=y
   | _ -> false

let is_exp_same_table e1 e2 = match (e1, e2) with
   | (Eq(a, _), Eq(b, _)) | (Eq(a, _), Lt(b, _)) | (Eq(a, _), Gt(b, _))
   | (Lt(a, _), Eq(b, _)) | (Lt(a, _), Lt(b, _)) | (Lt(a, _), Gt(b, _))
   | (Gt(a, _), Eq(b, _)) | (Gt(a, _), Lt(b, _)) | (Gt(a, _), Gt(b, _)) ->
         a=b
   | _ -> false

let rec is_conj_disjoint conj e = match conj with
   | And(a, b) -> (is_conj_disjoint a e) || (is_conj_disjoint b e)
   | Var p -> is_exp_disjoint p e
   | Not (Var p) -> not (is_exp_disjoint p e)
   | _ -> raise (Failure "Conj should only contain And, Var or Not(Var)")

let cmp_preds a b = match (a, b) with
   | (Eq(x, StringLit s1), Eq(y, StringLit s2)) when x=y -> compare s1 s2
   | (Gt(x, NumberLit n1), Gt(y, NumberLit n2)) when x=y -> compare n2 n1
   | (Lt(x, NumberLit n1), Lt(y, NumberLit n2)) when x=y -> compare n1 n2
   | (Eq(x, NumberLit n1), Eq(y, NumberLit n2)) when x=y -> compare n1 n2
   (* Lt < Gt < Eq *)
   | (Eq(x, _), Lt(y, _)) when x=y -> 1
   | (Eq(x, _), Gt(y, _)) when x=y -> 1
   | (Lt(x, _), Eq(y, _)) when x=y -> -1
   | (Lt(x, _), Gt(y, _)) when x=y -> -1
   | (Gt(x, _), Eq(y, _)) when x=y -> -1
   | (Gt(x, _), Lt(y, _)) when x=y -> 1
   | _ -> compare (var_to_string a) (var_to_string b)

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
   | Eq(Field _, (NumberLit _ | StringLit _ | IpAddr _ | Call _)) as p -> Var(p)
   | Lt(Field _, (NumberLit _ | Call _)) as p -> Var(p)
   | Gt(Field _, (NumberLit _ | Call _)) as p -> Var(p)
   | _ -> raise (Failure "Query not supported")

let rec conj_fold f acc conj = match conj with
   | And(((And(_,_) as c1)), ((And(_,_) as c2))) ->
         conj_fold f (conj_fold f acc c1) c2
   | And(((And(_,_) as c)), a)
   | And(a, ((And(_,_) as c))) ->
         conj_fold f (f acc a) c
   | And(a, b) ->
         f (f acc a) b
   | a -> f acc a


let cmp_conj_atom a b = match (a, b) with
   | (Not(Var(x)), Var(y)) when x = y -> 1
   | (Var(x), Not(Var(y))) when x = y -> -1
   | (Not(Var(x)), Not(Var(y)))
   | (Var(x), Not(Var(y)))
   | (Not(Var(x)), Var(y))
   | (Var(x), Var(y)) -> cmp_preds x y
   | _ ->
         raise (Failure "Conj should only contain Var or Not(Var)")

let conj_to_list c =
   List.sort cmp_conj_atom
      (conj_fold
         (fun acc x -> (match x with
            | Empty -> acc
            | _ -> x::acc)
         )
         [] c)

type evaled_formula =
   | False
   | True
   | Residual of formula

(* TODO: maybe this would be faster if the conj were represented by a list of
 * atoms, instead of an And() of atoms.
 *)
let rec partial_eval_conj resid_conj var value =
   let _not b = if b=False then True else True in
   match (resid_conj, var) with
   | ((True|False) as x, _) -> x
   | (Residual(Var x), Var y) when value=True && is_exp_disjoint x y -> False
   | (Residual(Var x), Var y) when value=False && is_exp_subset x y -> False
   | (Residual(Var x), Var y) when value=True && is_exp_subset y x -> True
   | (Residual(Var x), Var y) when x=y -> value
   | (Residual(Not(Var x)), Var y) when x=y -> _not value
   (*
   | (Residual(Var x), Var y) when value=True && is_exp_subset x y -> True
   | (Residual(Var x), Var y) when value=False && is_exp_disjoint x y -> True
   *)
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

(* Return a predicate in `conj` that's an ancestor of `pred`, if any. *)
let rec get_preceding_pred pred conj = match conj with
   | And(a, b) -> (match get_preceding_pred pred a with
         | None -> get_preceding_pred pred b
         | (Some _) as x -> x)
   | Var p when (cmp_preds p pred) < 0 -> Some (p, true)
   | Not (Var p) when (cmp_preds p pred) < 0 -> Some (p, false)
   | _ -> None

let rec get_first_pred conj = match conj with
   | And(a, b) -> get_first_pred a
   | Var p -> (p, true)
   | (Not (Var p)) -> (p, false)
   | _ -> raise (Failure "Bad format for conj")


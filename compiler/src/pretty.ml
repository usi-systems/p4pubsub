open Ast
open Format

let rec format_expr fmt = function
  | And(e1,e2) -> Format.fprintf fmt "%a and %a" format_expr e1 format_expr e2 
  | Or(e1,e2) -> Format.fprintf fmt "%a or %a" format_expr e1 format_expr e2 
  | Not(e1) -> Format.fprintf fmt "not %a" format_expr e1 
  | Lt(e1,e2) -> Format.fprintf fmt "%a < %a" format_expr e1 format_expr e2 
  | Gt(e1,e2) -> Format.fprintf fmt "%a > %a" format_expr e1 format_expr e2 
  | Eq(e1,e2) -> Format.fprintf fmt "%a = %a" format_expr e1 format_expr e2 
  | Ident(s) -> Format.fprintf fmt "%s" s
  | Number(n) -> Format.fprintf fmt "%d" n

let rec format_action_list fmt = function
  | al -> Format.fprintf fmt "%s" (String.concat ", " (List.map string_of_int al))

let format_query fmt = function
  | Query(e) -> Format.fprintf fmt "%a" format_expr e

let format_rule fmt = function
  | Rule(q, al) -> Format.fprintf fmt "%a : %a" format_query q format_action_list al

let format rule =
  let fmt = Format.std_formatter in 
  format_rule fmt rule

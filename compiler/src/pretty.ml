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
   
let rec format_query fmt = function
  | Query(e) -> Format.fprintf fmt "%a" format_expr e
   
let format ast = 
  let fmt = Format.std_formatter in 
  format_query fmt ast

open Ast
open Format

let string_of_ipaddr i =
   Printf.sprintf "%d.%d.%d.%d"
   ((i lsr 24) land 255)
   ((i lsr 16) land 255)
   ((i lsr 8)  land 255)
   (i land 255)

let rec format_expr fmt = function
  | And(e1,e2) -> Format.fprintf fmt "(%a and %a)" format_expr e1 format_expr e2
  | Or(e1,e2) -> Format.fprintf fmt "(%a or %a)" format_expr e1 format_expr e2
  | Not(e1) -> Format.fprintf fmt "(not %a)" format_expr e1
  | Lt(e1,e2) -> Format.fprintf fmt "%a < %a" format_expr e1 format_expr e2
  | Gt(e1,e2) -> Format.fprintf fmt "%a > %a" format_expr e1 format_expr e2
  | Eq(e1,e2) -> Format.fprintf fmt "%a = %a" format_expr e1 format_expr e2
  | Field(Some h, f) -> Format.fprintf fmt "%s.%s" h f
  | Field(None, f) -> Format.fprintf fmt "%s" f
  | NumberLit(n) -> Format.fprintf fmt "%d" n
  | StringLit(s) -> Format.fprintf fmt "\"%s\"" s
  | IpAddr(i) -> Format.fprintf fmt "%s" (string_of_ipaddr i)
  | Call(func, al) ->
        let rec format_arg_list fmt = function
         | (first, e::t) when first -> Format.fprintf fmt "%a%a" format_expr e format_arg_list (false, t)
         | (_, e::t) -> Format.fprintf fmt ", %a%a" format_expr e format_arg_list (false, t)
         | (_, []) -> Format.fprintf fmt ""
        in
        Format.fprintf fmt "%s(%a)" func format_arg_list (true, al)

let rec format_action_list fmt = function
  | al -> Format.fprintf fmt "%s" (String.concat ", " (List.map string_of_int al))

let format_query fmt = function
  | Query(e) -> Format.fprintf fmt "%a" format_expr e

let format_rule fmt = function
  | Rule(q, al) -> Format.fprintf fmt "%a : %a" format_query q format_action_list al

let format rule =
  let fmt = Format.std_formatter in
  format_rule fmt rule

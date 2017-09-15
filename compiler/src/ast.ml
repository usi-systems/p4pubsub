(* Parser and surface language types *)
type info = (int * int) * (int * int)

type expr =
  | And of expr * expr
  | Or of expr * expr
  | Not of expr
  | Lt of expr * expr
  | Gt of expr * expr
  | Eq of expr * expr
  | Field of string option * string
  | StringLit of string
  | NumberLit of int
  | IpAddr of int

type action_list = int list

type query = Query of expr

type rule = Rule of query * action_list

type rule_list = rule list

let field_name_for_pred p = match p with
   | Eq(Field(None, f), _) | Gt(Field(None, f), _) | Lt(Field(None, f), _) -> f
   | Eq(Field(Some h, f), _) | Gt(Field(Some h, f), _) | Lt(Field(Some h, f), _) -> h ^ "." ^ f
   | _ -> raise (Failure "Predicate should be in the form: f=n, f<n, f>n")

let table_name_for_pred p = match p with
   | Eq(Field(None, f), _) | Gt(Field(None, f), _) | Lt(Field(None, f), _) ->
         "tbl_" ^ f
   | Eq(Field(Some h, f), _) | Gt(Field(Some h, f), _) | Lt(Field(Some h, f), _) ->
         "tbl_" ^ h ^ "_" ^ f
   | _ -> raise (Failure "Predicate should be in the form: f=n, f<n, f>n")

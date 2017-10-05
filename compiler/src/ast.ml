(* Parser and surface language types *)
type info = (int * int) * (int * int)

type expr =
  | And of expr * expr
  | Or of expr * expr
  | Not of expr
  | Call of string * expr list
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

let field_for_pred p = match p with
   | Eq((Field _)as f, _) | Gt((Field _) as f, _) | Lt((Field _) as f, _) -> f
   | _ -> raise (Failure "Predicate should be in the form: f=n, f<n, f>n")

let field_name_for_pred p = match field_for_pred p with
   | Field(None, f) -> f
   | Field(Some h, f) -> h ^ "." ^ f
   | _ -> raise (Failure "Should be a field")

let table_name_for_pred p = match p with
   | Eq(Field(None, f), _) | Gt(Field(None, f), _) | Lt(Field(None, f), _) ->
         "query_" ^ f
   | Eq(Field(Some h, f), _) | Gt(Field(Some h, f), _) | Lt(Field(Some h, f), _) ->
         "query_" ^ h ^ "_" ^ f
   | _ -> raise (Failure "Predicate should be in the form: f=n, f<n, f>n")

let cmp_fields a b = match (a, b) with
   | (Field(Some h1, f1), Field(Some h2, f2)) when h1=h2 -> compare f1 f2
   | (Field(Some h1, _), Field(Some h2, _)) -> compare h1 h2
   | (Field(None, _), Field(Some _, _)) -> -1
   | (Field(Some _, _), Field(None, _)) -> 1
   | (Field(None, f1), Field(None, f2)) -> compare f1 f2
   | _ -> raise (Failure "Should be a field")

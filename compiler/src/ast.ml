(* Parser and surface language types *)
type info = (int * int) * (int * int)
                    
type expr =
  | And of expr * expr
  | Or of expr * expr
  | Not of expr 
  | Lt of expr * expr
  | Gt of expr * expr
  | Eq of expr * expr
  | Ident of string
  | Number of int

type action_list = int list

type query = Query of expr

type rule = Rule of query * action_list

type rule_list = rule list

let field_name_for_pred p = match p with
   | Eq(Ident(f), _) | Gt(Ident(f), _) | Lt(Ident(f), _) -> f
   | _ -> raise (Failure "Predicate should be in the form: f=n, f<n, f>n")

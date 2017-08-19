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

type query = Query of expr

open Core
open Bdd

module StringMap : module type of Map.Make(String)

module QueryLabel : sig
  type t = int
    [@@deriving compare, sexp]
  val format_t : t -> string
end

module QueryPred : sig
  type op = Lt | Gt | Eq
  type literal = string
  type t = literal * op * int
  type assignments = int StringMap.t (* map literals to assigned values *)
  val compare : t -> t -> int
  val equal : t -> t -> bool
  val format_t : t -> string
  val disjoint : t -> t -> bool
  val subset : t -> t -> bool
  val independent : t -> t -> bool
  val hash : t -> int

  val eval : assignments -> t -> bool
end

module QueryBdd : module type of Bdd(QueryPred)(QueryLabel)

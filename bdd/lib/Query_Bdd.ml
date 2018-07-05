open Core
open Bdd

module QueryLabel = struct
  type t = int
    [@@deriving compare, sexp]
  let compare = Pervasives.compare 
  let format_t = string_of_int
end

module StringMap = Map.Make(String)

module QueryPred = struct
  type op = Lt | Gt | Eq
  type literal = string
  type t = literal * op * int
  type assignments = int StringMap.t (* map literals to assigned values *)
  let compare (x: t) (y: t) =
    match x, y with
    | (a, _, _), (b, _, _) when a <> b -> Pervasives.compare a b
    | (_, Lt, _), (_, Gt, _)
    | (_, Lt, _), (_, Eq, _)
    | (_, Gt, _), (_, Eq, _) -> -1
    | (_, Eq, _), (_, Gt, _)
    | (_, Eq, _), (_, Lt, _)
    | (_, Gt, _), (_, Lt, _) -> 1
    | (_, Lt, j), (_, Lt, k) -> Pervasives.compare k j (* reversed  for Lt *)
    | (_, _, j), (_, _, k) -> Pervasives.compare j k

  let equal (x: t) (y:t) = x = y
  let format_t (x: t) =
    match x with
    | (l, Lt, i) -> l ^ " < " ^ (string_of_int i)
    | (l, Gt, i) -> l ^ " > " ^ (string_of_int i)
    | (l, Eq, i) -> l ^ " = " ^ (string_of_int i)

  let disjoint (x: t) (y: t) =
    match x, y with
    | (a, _, _), (b, _, _) when a <> b -> false
    | (_, Lt, _), (_, Lt, _)
    | (_, Gt, _), (_, Gt, _) -> false
    | (_, Lt, j), (_, Gt, k)
    | (_, Gt, k), (_, Lt, j) -> j <= (k+1)
    | (_, Eq, j), (_, Gt, k)
    | (_, Gt, k), (_, Eq, j) -> j <= k
    | (_, Eq, j), (_, Lt, k)
    | (_, Lt, k), (_, Eq, j) -> j >= k
    | (_, Eq, j), (_, Eq, k) -> j <> k

  (* if sub is true, then sup must be true *)
  let subset (sub: t) (sup: t) =
    match sub, sup with
    | (a, _, _), (b, _, _) when a <> b -> false
    | (_, Eq, j), (_, Eq, k) -> k = j
    | (_, Gt, j), (_, Gt, k) -> k <= j
    | (_, Lt, j), (_, Lt, k) -> k >= j
    | (_, Eq, j), (_, Gt, k) -> k < j
    | (_, Eq, j), (_, Lt, k) -> k > j
    | _ -> false


  let independent (x: t) (y: t) =
    match x, y with
    | (a, _, _), (b, _, _) -> a <> b

  let hash (x: t) = Hashtbl.hash x

  let eval (a: assignments) (x: t) : bool =
    match x with
    | l, Lt, i -> (StringMap.find_exn a l) < i
    | l, Gt, i -> (StringMap.find_exn a l) > i
    | l, Eq, i -> (StringMap.find_exn a l) = i

end

module QueryBdd = Bdd(QueryPred)(QueryLabel)

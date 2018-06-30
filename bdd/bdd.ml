open Core

(*
 * Based on: https://braibant.github.io/update/2014/06/17/bdd-1.html
 *)

type uid = int

module StringMap = Map.Make(String)

module Var = struct
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

  let subset (sub: t) (sup: t) =
    match sub, sup with
    | (a, _, _), (b, _, _) when a <> b -> false
    | (_, Eq, j), (_, Eq, k) -> k = j
    | (_, Gt, j), (_, Gt, k) -> k <= j
    | (_, Lt, j), (_, Lt, k) -> k >= j
    | (_, Eq, j), (_, Gt, k) -> k < j
    | (_, Eq, j), (_, Lt, k) -> k > j
    | _ -> false

  let hash (x: t) = Hashtbl.hash x

  let eval (x: t) (a: assignments) : bool =
    match x with
    | l, Lt, i -> (StringMap.find_exn a l) < i
    | l, Gt, i -> (StringMap.find_exn a l) > i
    | l, Eq, i -> (StringMap.find_exn a l) = i

end

type bdd_label = int

type bdd_node =
| L of leaf
| N of decision_node
and leaf = {leaf_uid: uid; labels: bdd_label list}
and decision_node = {uid: uid; var: Var.t; low: bdd_node; high: bdd_node }

let uid = function
  | L l -> l.leaf_uid
  | N n -> n.uid

let node_equal x y =
  match x, y with
  | N n1, N n2 ->
      Var.compare n1.var n2.var = 0
      && uid n1.low = uid n2.low
      && uid n1.high = uid n2.high
  | L l1, L l2 ->
      l1.labels = l2.labels
  | N _, L _ | L _, N _ -> false


module NodeH = struct
  type t = bdd_node
  let equal = node_equal
  let hash node =
    match node with
    | N n ->
        (Hashtbl.hash (Var.hash n.var, uid n.low, uid n.high)) land Int.max_value
    | L l ->
        (Hashtbl.hash l.labels) land Int.max_value
end

module NodeWeakHS = Caml.Weak.Make(NodeH)
let table = NodeWeakHS.create 1337 (* weak hash set*)
let next_uid = ref 2      (* global uid counter *)


let mk_node var low high =
  if uid low = uid high
  then low
  else
    begin
      let n1 = N {uid = !next_uid; var; low; high} in
      let n2 = NodeWeakHS.merge table n1 in
      if phys_equal n1 n2
      then incr next_uid;
      n2
    end

let mk_leaf lbls =
  let l1 = L {leaf_uid = !next_uid; labels = lbls} in
  let l2 = NodeWeakHS.merge table l1 in
  if phys_equal l1 l2
    then incr next_uid;
  l2

let empty_leaf = mk_leaf []

let rec mergebdd x y =
  match x, y with
  | L {labels = lbls1}, L {labels = lbls2} ->                 (* both leaves *)
      mk_leaf (List.dedup_and_sort (lbls1 @ lbls2))
  | (L _ as l), N {var = var; low = low; high = high; _}
  | N {var = var; low = low; high = high; _}, (L _ as l) ->   (* leaf and node *)
      mk_node var (mergebdd low l) (mergebdd high l)
  | N {var = var1; low = low1; high = high1; _},
    N {var = var2; low = low2; high = high2; _} ->            (* both nodes *)
    let cmp = Var.compare var1 var2 in
    if cmp < 0
    then (* var1 < var2 *)
      begin
        if Var.disjoint var1 var2
        then
          mk_node var1 (mergebdd low1 y) (mergebdd low2 high1)
        else if Var.subset var2 var1
        then
          mk_node var1 (mergebdd low1 low2) (mergebdd high1 y)
        else
          mk_node var1 (mergebdd low1 y) (mergebdd high1 y)
      end
    else if cmp = 0
    then (* var1 = var2  *)
      mk_node var1 (mergebdd low1 low2) (mergebdd high1 high2)
    else (* var1 > var2 *)
      begin
        if Var.disjoint var1 var2
        then
          mk_node var2 (mergebdd x low2) (mergebdd low1 high2)
        else if Var.subset var1 var2
        then
          mk_node var2 (mergebdd low1 low2) (mergebdd x high2)
        else
          mk_node var2 (mergebdd x low2) (mergebdd x high2)
      end

let fmt_lbls (lbls:int list) : string =
  String.concat ~sep:", " (List.map ~f:string_of_int lbls)

let write_dot (bdd:bdd_node) : unit =
  let oc = Out_channel.create "out.dot" in
  let visited = Caml.Hashtbl.create 1337 in
  let rec w (u:bdd_node) : unit =
    if not (Caml.Hashtbl.mem visited u) then
      begin
        Caml.Hashtbl.add visited u 0;
        match u with
        | N {uid = i; var = v; low = l; high = h;} ->
            Printf.fprintf oc "n%d [label=\"%s\"];\n" i (Var.format_t v);
            Printf.fprintf oc "n%d -> n%d [style=\"dashed\"];\n" i (uid l);
            Printf.fprintf oc "n%d -> n%d;\n" i (uid h);
            w l; w h
        | L {leaf_uid = i; labels = lbls } ->
            Printf.fprintf oc "n%d [label=\"%s\" shape=box];\n" i (fmt_lbls lbls)
      end
  in
  Printf.fprintf oc "digraph G {\n";
  w bdd;
  Printf.fprintf oc "}";
  Out_channel.close oc

type true_or_false_var =
  | T of Var.t
  | F of Var.t

type conjunction =
  true_or_false_var list

let rec conj_to_bdd (formula:conjunction) lbl =
  match formula with
  | T q::[] -> mk_node q empty_leaf (mk_leaf [lbl])
  | F q::[] -> mk_node q (mk_leaf [lbl]) empty_leaf
  | T q::t -> mk_node q empty_leaf (conj_to_bdd t lbl)
  | F q::t -> mk_node q (conj_to_bdd t lbl) empty_leaf
  | _ -> raise (Failure "unreachable")

let rec eval_bdd (u:bdd_node) (a: Var.assignments) : bdd_label list =
  match u with
  | N {var = v; low = l; high = h} ->
      if Var.eval v a then
        eval_bdd h a
      else
        eval_bdd l a
  | L {labels = lbls} -> lbls


let () =
  let open Var in
  (*
  let a = conj_to_bdd [T("a", Eq, 1); T("b", Eq, 2); T("c", Eq, 3)] 1 in
  let b = conj_to_bdd [T("a", Gt, 0); F("b", Eq, 2); T("c", Eq, 3)] 2 in
  let c = conj_to_bdd [T("a", Gt, 1); T("b", Eq, 4); T("c", Eq, 3)] 3 in
  let a = conj_to_bdd [T("a", Eq, 3)] 1 in
  let b = conj_to_bdd [T("a", Gt, 1)] 2 in
  let c = conj_to_bdd [T("a", Gt, 2)] 3 in
  let d = conj_to_bdd [T("a", Lt, 2)] 4 in
  *)
  let a = conj_to_bdd [T("a", Eq, 3); F("b", Eq, 3)] 1 in
  let b = conj_to_bdd [T("a", Gt, 1); T("b", Eq, 4)] 2 in
  let c = conj_to_bdd [T("a", Gt, 2); T("b", Gt, 2)] 3 in
  let d = conj_to_bdd [T("a", Lt, 2); T("b", Lt, 1)] 4 in
  let merged = mergebdd a b in
  let merged = mergebdd merged c in
  let merged = mergebdd merged d in
  write_dot merged;
  ()
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

let rec prune_implicit (ancestor:Var.t) (is_high_branch:bool) (n:bdd_node) =
  match n with
  | N {var = var; high = high; low = low; _} ->
      if Var.independent ancestor var
      then
        n
      else if is_high_branch && Var.disjoint ancestor var then
        prune_implicit ancestor is_high_branch low
      else if is_high_branch && Var.subset ancestor var then
        prune_implicit ancestor is_high_branch high
      else if (not is_high_branch) && Var.subset var ancestor then
        prune_implicit ancestor is_high_branch low
      else
        mk_node var (prune_implicit ancestor is_high_branch low) (prune_implicit ancestor is_high_branch high)
  | L _ -> n

let rec mergebdd (x:bdd_node) (y:bdd_node) : bdd_node =
  let x,y = match x, y with (* order x and y if they are both internal (decision) nodes *)
  | N {var = var1; _}, N {var = var2; _} ->
      if (Var.compare var1 var2) < 0 then (x,y) else (y,x)
  | _ -> (x, y)
  in
  match x, y with
  | L {labels = lbls1}, L {labels = lbls2} ->                 (* both leaves *)
      mk_leaf (List.dedup_and_sort (lbls1 @ lbls2))
  | L {labels = []; _}, (N {var = var; low = low; high = high; _} as n)
  | (N {var = var; low = low; high = high; _} as n), L {labels = []; _} ->   (* empty leaf and decision node *)
      n (* this is an optimization; we don't need to push the empty leaf all the way down all branches *)
  | (L _ as l), N {var = var; low = low; high = high; _}
  | N {var = var; low = low; high = high; _}, (L _ as l) ->   (* leaf and decision node *)
      mk_node var (mergebdd low l) (mergebdd high l)
  | N {var = var1; low = low1; high = high1; _},              (* both decision nodes *)
    N {var = var2; low = low2; high = high2; _} when Var.equal var1 var2 ->
      mk_node var1 (mergebdd low1 low2) (mergebdd high1 high2)
  | N {var = var1; low = low1; high = high1; _}, (* already sorted; var1 comes before var2 in the BDD ordering *)
    N {var = var2; low = low2; high = high2; _} ->            (* both nodes *)
      begin
        if Var.disjoint var1 var2
        then
          mk_node var1 (mergebdd low1 (prune_implicit var1 false y)) (mergebdd (prune_implicit var1 true low2) high1)
        else if Var.subset var2 var1 (* var2=true --> var1=true *)
        then
          mk_node var1 (mergebdd low1 (prune_implicit var1 false low2)) (mergebdd high1 (prune_implicit var1 true y))
        else if Var.subset var1 var2 (* var1=true --> var2=true *)
        then
          mk_node var1 (mergebdd low1 (prune_implicit var1 false y)) (mergebdd high1 (prune_implicit var1 true high2))
        else
          mk_node var1 (mergebdd low1 (prune_implicit var1 false y)) (mergebdd high1 (prune_implicit var1 true y))
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
            Printf.fprintf oc "n%d [label=\"%s\" shape=box style=filled] {rank=sink; n%d};\n" i (fmt_lbls lbls) i
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


let mk_queries num_queries =
  let open Var in
  let rec range a b =
    if a > b then []
    else a :: range (a+1) b
  in
  let queries =
    List.fold_left ~init:[] ~f:(fun l _ ->
      let a, b, c = (Random.int 101), (Random.int 1001), (Random.int 201) in
      ([T("a", Eq, a); T("b", Gt, b)], c)::l) (range 0 num_queries)
  in
  queries


let mk_queries_bdd queries =
  let cnt = ref 0 in
  let last_time = ref (Unix.gettimeofday ()) in
  let merged =
    List.fold_left ~init:empty_leaf ~f:(fun m (c, i) ->
      cnt := !cnt + 1;
      if !cnt mod 1000 = 0
      then
        begin
          let time_now = Unix.gettimeofday () in
          Printf.printf "%d\t%f\n" !cnt (time_now -. !last_time);
          Out_channel.flush stdout;
          last_time := time_now;
        end;
      mergebdd m (conj_to_bdd c i))
    queries
  in
  merged

let () =
  let open Var in
  (*
  let merged = empty_leaf in
  let a = conj_to_bdd [T("a", Eq, 1); T("b", Eq, 2); T("c", Eq, 3)] 1 in
  let b = conj_to_bdd [T("a", Gt, 0); F("b", Eq, 2); T("c", Eq, 3)] 2 in
  let c = conj_to_bdd [T("a", Gt, 1); T("b", Eq, 4); T("c", Eq, 3)] 3 in
  let a = conj_to_bdd [T("a", Eq, 3)] 1 in
  let b = conj_to_bdd [T("a", Gt, 1)] 2 in
  let c = conj_to_bdd [T("a", Gt, 2)] 3 in
  let d = conj_to_bdd [T("a", Lt, 2)] 4 in
  let a = conj_to_bdd [T("b", Eq, 3)] 1 in
  let b = conj_to_bdd [T("b", Eq, 4)] 2 in
  let c = conj_to_bdd [T("b", Gt, 2)] 3 in
  let d = conj_to_bdd [T("b", Lt, 1)] 4 in
  let a = conj_to_bdd [T("a", Eq, 3); T("b", Eq, 3)] 1 in
  let b = conj_to_bdd [T("a", Gt, 1); T("b", Eq, 4)] 2 in
  let c = conj_to_bdd [T("a", Gt, 2); T("b", Gt, 2)] 3 in
  let d = conj_to_bdd [T("a", Lt, 2); T("b", Lt, 1)] 4 in
  let merged = mergebdd merged d in
  let merged = mergebdd merged c in
  let merged = mergebdd merged b in
  let merged = mergebdd merged a in
  *)

  Random.init 1337;

  let queries = mk_queries 40000 in
  let merged = mk_queries_bdd queries in

  write_dot merged;
  let asn = List.fold_left ~init:StringMap.empty ~f:(fun m (l, i) -> StringMap.set m l i)
    [("a", 3); ("b", 4)] in
  let x = eval_bdd merged asn in
  Printf.printf " [ %s ]\n" (fmt_lbls x);

  ()

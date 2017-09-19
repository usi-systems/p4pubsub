open Ast
open Formula
open Dnf

module IntSet = Set.Make(struct let compare = Pervasives.compare type t = int end)

type leaf_value = int list

type bdd_node =
   | Node of variable * int * int
   | Leaf of leaf_value

type bdd_struct = {
   mutable vars: variable list;
   mutable root: int;
   empty_leaf: int;
   mutable last_node_id: int;
   mutable n: int;
   mutable rules: (formula * int list) list;
   tbl: (int, bdd_node) Hashtbl.t;
   tbl_inv: (bdd_node, int) Hashtbl.t;
}

let mk_pred_list t =
   List.sort_uniq cmp_preds
      (fold_vars (fun acc a -> a::acc) [] t)

let merge_pred_list l1 l2 =
   List.sort cmp_preds ((List.filter (fun e -> not (List.mem e l1)) l2) @ l1)

let leaf_value_to_string lv =
   "[" ^ (String.concat ", " (List.map (fun v -> Printf.sprintf "%d" v) lv)) ^ "]"

let int_exp x y = (float_of_int x) ** (float_of_int y) |> int_of_float

let list_concat_uniq l1 l2 =
   List.sort compare ((List.filter (fun e -> not (List.mem e l1)) l2) @ l1)


let bdd_to_string ?graph_name:(g="digraph G") ?node_ns:(ns="") bdd =
   let color_list = ["brown"; "red"; "green"; "blue"; "yellow"; "cyan"; "orange"] in
   let rep a b = Str.global_replace (Str.regexp_string a) b in
   let escape s = rep "\"" "\\\"" s in
   let last_color = ref 0 in
   let next_color () =
      last_color := (!last_color + 1) mod (List.length color_list);
      List.nth color_list !last_color
   in
   let color_tbl = Hashtbl.create 10 in
   let color v =
      let field = table_name_for_pred v in
      if not (Hashtbl.mem color_tbl field) then
         Hashtbl.add color_tbl field (next_color ()) else ();
      Hashtbl.find color_tbl field
   in
   (Printf.sprintf "%s {\n" g) ^
   "rank=out; graph [pad=\"0.1\", nodesep=\"0.5\", ranksep=\"1\"];
    node [margin=\"0.01\"];\n" ^
   (Hashtbl.fold (fun u node s ->
      s ^ (match node with
      | Node(a, low, high) ->
            Printf.sprintf "%sn%d [label=\"%s\" color=\"%s\"];\n%sn%d -> %sn%d [style=\"dashed\"];\n%sn%d -> %sn%d;\n"
            ns u (escape (var_to_string a)) (color a) ns u ns low ns u ns high
      | Leaf lv -> Printf.sprintf "%sn%d [label=\"%s\" shape=box style=filled]
      {rank=sink; %sn%d};\n" ns u (leaf_value_to_string lv) ns u
      )
   )
   bdd.tbl "") ^
   "}\n"

let print_bdd ?graph_name:(g="digraph G") ?node_ns:(ns="") bdd = print_endline (bdd_to_string ~graph_name:g ~node_ns:ns bdd)


let bdd_init initial_size =
   let bdd = {
      (* TODO: find a more reasonable initial tree size here *)
      tbl_inv = Hashtbl.create initial_size;
      tbl = Hashtbl.create initial_size;
      root = 1;
      empty_leaf = 1;
      last_node_id = 1;
      vars = [];
      rules = [];
      n = 0;
      }
   in
   Hashtbl.add bdd.tbl bdd.root (Leaf []);
   bdd


let get_next_node_id bdd =
   bdd.last_node_id <- bdd.last_node_id + 1;
   bdd.last_node_id

let bdd_mk_node bdd node =
      (*
   try
      let u = Hashtbl.find bdd.tbl_inv node in
      print_endline (Printf.sprintf "// Found node %d" u);
      u
   with Not_found ->
      *)
      let u = get_next_node_id bdd in
      Hashtbl.add bdd.tbl u node;
      (*
      Hashtbl.add bdd.tbl_inv node u;
      *)
      (*
      Hashtbl.add bdd.tbl_inv node u;
      *)
      u


let rec clone_tree bdd clone_map u =
   if u=bdd.empty_leaf then u
   else (
      try
         let u2 = Hashtbl.find clone_map u in
         u2
      with
      Not_found ->
         let node = (match Hashtbl.find bdd.tbl u with
            | Node(p, l, h) ->
                  Node(p, clone_tree bdd clone_map l, clone_tree bdd clone_map h)
            | (Leaf _) as x -> x
         )
         in
         let u2 = get_next_node_id bdd in
         Hashtbl.add bdd.tbl u2 node;
         Hashtbl.add clone_map u u2;
         u2
   )

(* Clone the child to create p's new high branch *)
let rec clone_high_branch bdd clone_map p u =
   if u=bdd.empty_leaf then u
   else (
      try
         Hashtbl.find clone_map u
      with
      Not_found -> (
         match Hashtbl.find bdd.tbl u with
         | Node(p2, l, _) when is_exp_disjoint p p2 ->
               clone_high_branch bdd clone_map p l
         | Node(p2, _, h) when is_exp_subset p p2 ->
               clone_high_branch bdd clone_map p h
         | Node(p2, l, h) ->
               let l2, h2 = clone_high_branch bdd clone_map p l,
                                   clone_high_branch bdd clone_map p h in
               if l2=h2 then
                  l2
               else (
                  let u2 = get_next_node_id bdd in
                  let node = Node(p2, l2, h2) in
                  Hashtbl.add bdd.tbl u2 node;
                  Hashtbl.add clone_map u u2;
                  u2
               )
         | (Leaf _) as node ->
               let u2 = get_next_node_id bdd in
               Hashtbl.add bdd.tbl u2 node;
               Hashtbl.add clone_map u u2;
               u2
      )
   )

let bdd_prune_unreachable bdd =
   let reachable = Hashtbl.create (Hashtbl.length bdd.tbl) in
   let getn u = Hashtbl.find bdd.tbl u in
   let rec find_reachable u =
      Hashtbl.add reachable u 0;
      match getn u with
      | Node(_, l, h) -> find_reachable l; find_reachable h
      | Leaf _ -> ()
   in
   find_reachable bdd.root;
   Hashtbl.iter (fun u node ->
      if not (Hashtbl.mem reachable u) then (
         Hashtbl.remove bdd.tbl u;
         try Hashtbl.remove bdd.tbl_inv node
         with Not_found -> ()
      )
   ) bdd.tbl

let rec rm_tree bdd del_map u =
   if u <> bdd.empty_leaf then
   try Hashtbl.find del_map u
   with
   Not_found -> (
      (match Hashtbl.find bdd.tbl u with
      | Node(_, l, h) ->
            rm_tree bdd del_map l;
            rm_tree bdd del_map h
      | Leaf _ -> ()
      );
      Hashtbl.add del_map u ();
      ()
   )

let rec prune_low_branch bdd prune_map p u =
   try
      Hashtbl.find prune_map u
   with
   Not_found -> (
      match Hashtbl.find bdd.tbl u with
      | Node(p2, l, h) when is_exp_subset p2 p ->
            let u2 = prune_low_branch bdd prune_map p l in
            Hashtbl.add prune_map u u2;
            u2
      | Node(p2, l, h) ->
            let node = Node(p2, prune_low_branch bdd prune_map p l,
                                prune_low_branch bdd prune_map p h) in
            Hashtbl.replace bdd.tbl u node;
            Hashtbl.add prune_map u u;
            u
      | Leaf _ -> u
   )


let rec reduce_tree bdd red_map u =
   try
      let u2 = Hashtbl.find red_map u in
      u2
   with Not_found -> (
      let old_node = Hashtbl.find bdd.tbl u in
      let new_node = match old_node with
         | Node(p, l, h) ->
               let l2, h2 = reduce_tree bdd red_map l,
                            reduce_tree bdd red_map h in
               if l2 = h2 then
                  Hashtbl.find bdd.tbl l2
               else
                  Node(p, l2, h2)

         | (Leaf _) as leaf -> leaf
      in
      try
         let u2 = Hashtbl.find bdd.tbl_inv new_node in
         Hashtbl.add red_map u u2;
         u2
      with Not_found ->
         Hashtbl.replace bdd.tbl u new_node;
         Hashtbl.add bdd.tbl_inv new_node u;
         Hashtbl.add red_map u u;
         u
   )

let bdd_add_node bdd parent child p visitor =
   let getn u = Hashtbl.find bdd.tbl u in
   let update_parent u =
      if parent=0 then (
         bdd.root <- u
      )
      else (
         let old_parent_node = getn parent in
         let new_parent_node = match old_parent_node with
            | Node(pp, pl, ph) when pl=child -> Node(pp, u, ph)
            | Node(pp, pl, ph) when ph=child -> Node(pp, pl, u)
            | _ -> raise (Failure "Parent should be a node")
         in
         Hashtbl.replace bdd.tbl parent new_parent_node;
         ()
      )
   in
   match getn child with
   | Leaf [] when child=bdd.empty_leaf ->
         let h = get_next_node_id bdd in
         let leaf2 = Leaf [] in
         let u = bdd_mk_node bdd (Node(p, bdd.empty_leaf, h)) in
         Hashtbl.add bdd.tbl h leaf2;
         update_parent u;
         visitor parent u
   | Leaf [] -> (* this is a path we're working on pushing down *)
         let u = bdd_mk_node bdd (Node(p, bdd.empty_leaf, child)) in
         update_parent u;
         visitor parent u
   | (Leaf _) as leaf -> (* this is a terminal leaf of other formulas *)
         let u = bdd_mk_node bdd (Node(p, child, bdd_mk_node bdd leaf)) in
         update_parent u;
         visitor parent u
   | Node _ ->
         let child_clone = clone_high_branch bdd (Hashtbl.create 100) p child in
         let pruned_child = prune_low_branch bdd (Hashtbl.create 100) p child in
         let u = bdd_mk_node bdd (Node(p, pruned_child, child_clone)) in
         update_parent u;
         visitor parent u;
         ()

let bdd_add_query bdd disj actions =
   let getn u = Hashtbl.find bdd.tbl u in
   let rec visitor resid parent u =
      match (getn u, resid) with
      | (_, False) -> () (* formula is false down this path. stop. *)
      | (Leaf _, Residual conj) ->
            let p2,_ = get_first_pred conj in
            bdd_add_node bdd parent u p2 (visitor resid)
      | (Leaf [], True) when u=bdd.empty_leaf ->
            let l2 = bdd_mk_node bdd (Leaf actions) in
            (* Update parent to point to this leaf instead *)
            (match getn parent with
               | Node(pp, pl, ph) when pl=bdd.empty_leaf ->
                     let new_node = Node(pp, l2, ph) in
                     Hashtbl.replace bdd.tbl parent new_node
               | Node(pp, pl, ph) when ph=bdd.empty_leaf ->
                     let new_node = Node(pp, pl, l2) in
                     Hashtbl.replace bdd.tbl parent new_node
               | _ -> raise (Failure "Parent should be a node")
            )

      | (Leaf [], True) ->
            let new_leaf = Leaf actions in
            Hashtbl.replace bdd.tbl u new_leaf;
      | (Leaf a, True) ->
            assert (u <> bdd.empty_leaf);
            let new_leaf = Leaf(list_concat_uniq a actions) in
            Hashtbl.replace bdd.tbl u new_leaf;
      | (Node(p, l, h), Residual conj) -> (match get_preceding_pred p conj with
         | None ->
               visitor (partial_eval_conj resid (Var p) False) u l;
               visitor (partial_eval_conj resid (Var p) True) u h
         | Some (p2, _) ->
               bdd_add_node bdd parent u p2 (visitor resid)
         )
      | (Node(p, l, h), True) ->
               visitor True u l;
               visitor True u h
   in
   bdd.rules <- ([(disj, actions)] @ bdd.rules);
   bdd.vars <- merge_pred_list bdd.vars (mk_pred_list disj);
   bdd.n <- List.length bdd.vars;
   print_string (Printf.sprintf "// Adding disj %d: " (List.length bdd.rules)); print_form disj;
   List.iter
      (fun c -> visitor (Residual (list_to_conj c)) 0 bdd.root)
      (disj_to_list disj);
   Hashtbl.clear bdd.tbl_inv;
   let red_map = Hashtbl.create (Hashtbl.length bdd.tbl) in
   bdd.root <- reduce_tree bdd red_map bdd.root;
   bdd_prune_unreachable bdd;
   ()


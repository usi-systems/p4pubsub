open Ast
open Formula
open Dnf

module IntSet = Set.Make(struct let compare = Pervasives.compare type t = int end)

type leaf_value = int list

type bdd_node =
   | Node of variable * int * int
   | Leaf of leaf_value

type bdd_struct = {
   vars: variable list;
   mutable root: int;
   n: int;
   mutable rules: (formula * int list) list;
   tbl: (int, bdd_node) Hashtbl.t;
}

let leaf_value_to_string lv =
   "[" ^ (String.concat ", " (List.map (fun v -> Printf.sprintf "%d" v) lv)) ^ "]"

let int_exp x y = (float_of_int x) ** (float_of_int y) |> int_of_float

let bdd_to_string ?graph_name:(g="G") bdd =
   (Printf.sprintf "digraph %s {\n" g) ^
   (Hashtbl.fold (fun u node s ->
      s ^ (match node with
      | Node(a, low, high) ->
            Printf.sprintf "n%d [label=\"%s\"];\nn%d -> n%d [style=\"dashed\"];\nn%d -> n%d;\n"
            u (var_to_string a) u low u high
      | Leaf lv -> Printf.sprintf "n%d [label=\"%s\" shape=box style=filled]
      {rank=sink; n%d};\n" u (leaf_value_to_string lv) u
      )
   )
   bdd.tbl "") ^
   "legend [shape=box label=\"" ^
   (List.fold_left (fun s r -> s ^ (match r with (t, lv) ->
      Printf.sprintf "%s : %s\\l"
                                    (formula_to_string t)
                                    (leaf_value_to_string lv))) "" bdd.rules) ^

   "\"];\n}\n"

let print_bdd ?graph_name:(g="G") bdd = print_endline (bdd_to_string ~graph_name:g bdd)


(* This removes redundant predicates from the BDD. If the predicate of a node's
 * child is redundant, the child is replaced with either the child's low or
 * high branch. This is performed recursively until a non-redundant child is
 * encountered.
 *
 * TODO: don't just check immediate children for redundancy, but entire
 * subtree. This will only be needed when it's possible to have redundant
 * predicats that aren't adjacent.
 *)
let bdd_rm_redundant_preds bdd =
   let getn u = Hashtbl.find bdd.tbl u in
   let rm u = Hashtbl.remove bdd.tbl u in
   let rec rm_tree u = (match getn u with
      | Node(_, l, h) -> rm_tree l; rm_tree h
      | Leaf _ -> ());
      rm u
   in
   let rep u n = Hashtbl.replace bdd.tbl u n in
   let rec check_redundant u = match getn u with
      | Node(p, l, h) -> (match (getn l, getn h) with
         | (_, Node(p2, hl, hh)) when is_exp_subset p p2 -> 
               rm h;
               rm_tree hh;
               rep u (Node(p, l, hl));
               check_redundant u
         | (_, Node(p2, hl, hh)) when is_exp_disjoint p p2 -> 
               rm h;
               rm_tree hh;
               rep u (Node(p, l, hl));
               check_redundant u
         | (Node(p2, ll, lh), _) when is_exp_subset p2 p ->
               rm l;
               rm_tree lh;
               rep u (Node(p, ll, h));
               check_redundant u
         | (Node _, Node _) -> 
               check_redundant l; check_redundant h
         | (Leaf _, Leaf _) -> ()
         | _ -> ())
      | Leaf _ -> raise (Failure "This should never be applied to a leaf")
   in
   check_redundant bdd.root


let bdd_init (sorted_vars: variable list) =
   let bdd = {
      tbl = Hashtbl.create (int_exp 2 (List.length sorted_vars));
      root = 1;
      vars = sorted_vars;
      rules = [];
      n = List.length sorted_vars;}
   in
   let height = List.length sorted_vars in
   let rec add_nodes var depth i =
      let u = ((int_exp 2 depth) + i) in
      let (low, high) = ((2*u), (2*u)+1) in
      Hashtbl.add bdd.tbl u (Node(var, low, high));
      if depth+1=height then (
         Hashtbl.add bdd.tbl low (Leaf []);
         Hashtbl.add bdd.tbl high (Leaf []));
      if i = 0 then (depth+1) else add_nodes var depth (i-1)
   in
   let add_var depth var =
      add_nodes var depth ((int_exp 2 depth)-1)
   in
   ignore (List.fold_left add_var 0 sorted_vars);
   bdd_rm_redundant_preds bdd;
   bdd



let mk_var_list t =
   List.sort_uniq cmp_vars
      (fold_vars (fun acc a -> a::acc) [] t)

let rec bdd_insert bdd disj actions =
   let list_concat_uniq l1 l2 =
      l1 @ (List.filter (fun e -> not (List.mem e l1)) l2)
   in
   let rec add_conj u resid_conj = match (Hashtbl.find bdd.tbl u, resid_conj) with
      | (_, False) -> () (* the conjunction is false down this path. stop. *)
      | (Leaf _, Residual _) -> () (* the conj is not fully evaluated on this path *)
      | (Node(v, l, h), _) ->
            add_conj l (partial_eval_conj resid_conj (Var v) False);
            add_conj h (partial_eval_conj resid_conj (Var v) True);
      | (Leaf a, True) ->
            Hashtbl.replace bdd.tbl u (Leaf(list_concat_uniq a actions))
   in
   bdd.rules <- ([(disj, actions)] @ bdd.rules);
   List.iter
      (fun c -> add_conj bdd.root (Residual (list_to_conj c)))
      (disj_to_list disj)

let bdd_replace_node bdd u1 u2 =  
   Hashtbl.filter_map_inplace (fun u node -> Some(match node with
      | Node(x, l, h) when l=u1 && h=u1 -> Node(x, u2, u2)
      | Node(x, l, h) when l=u1 -> Node(x, u2, h)
      | Node(x, l, h) when h=u1 -> Node(x, l, u2)
      | _ -> node)
   ) bdd.tbl

let bdd_remove_dupes bdd =
   let rep = bdd_replace_node bdd in
   let find_dupes u node dup_set = IntSet.union dup_set (
      if IntSet.mem u dup_set then
         IntSet.empty
      else
         (Hashtbl.fold (fun u2 node2 d -> 
            if node2=node && u2!=u then (rep u2 u; IntSet.add u2 d) else d)
         bdd.tbl
         IntSet.empty))
   in
   let dupes =
      Hashtbl.fold find_dupes bdd.tbl IntSet.empty
   in
   Hashtbl.filter_map_inplace
      (fun u node -> if (IntSet.mem u dupes) then None else Some node)
      bdd.tbl

let bdd_reduce bdd =
   let getn u = Hashtbl.find bdd.tbl u in
   let rm_redundant u node = match node with
      | Node(_, l, h) when l=h ->
            bdd_replace_node bdd u l; None
      | _ -> Some node
   in
   (* remove nodes whose high child is `Leaf []` (i.e. drop) *)
   let rm_high_drop u node = match node with
      | Node(_, l, h) -> (match getn h with
               | Leaf [] -> bdd_replace_node bdd u l; None
               | _ -> Some node)
      | _ -> Some node
   in
   (* remove when high child is equal to low child's low *)
   let rm_high_low_low u node = match node with
      | Node(_, l, h) -> (match getn l with
               | Node(_, ll, _) when h=ll-> bdd_replace_node bdd u l; None
               | _ -> Some node)
      | _ -> Some node
   in
   let rec repeat_reduce prev_len =
      bdd_remove_dupes bdd;
      Hashtbl.filter_map_inplace rm_high_drop bdd.tbl;
      Hashtbl.filter_map_inplace rm_high_low_low bdd.tbl;
      Hashtbl.filter_map_inplace rm_redundant bdd.tbl;
      if prev_len = Hashtbl.length bdd.tbl then
         ()
      else repeat_reduce (Hashtbl.length bdd.tbl)
   in
   let find_root () = 
      Hashtbl.fold (fun u _ v -> min u v) bdd.tbl max_int
   in
   repeat_reduce (Hashtbl.length bdd.tbl);
   bdd.root <- find_root ()

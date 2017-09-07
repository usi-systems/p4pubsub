open Ast
open Formula
open Dnf

module IntSet = Set.Make(struct let compare = Pervasives.compare type t = int end)

type leaf_value = int list

type bdd_node =
   | Node of atom * int * int 
   | Leaf of leaf_value

type bdd_struct = {
   vars: atom list;
   mutable root: int;
   n: int;
   tbl: (int, bdd_node) Hashtbl.t;
}

let leaf_value_to_string lv =
   "[" ^ (String.concat ", " (List.map (fun v -> Printf.sprintf "%d" v) lv)) ^ "]"

let int_exp x y = (float_of_int x) ** (float_of_int y) |> int_of_float

let bdd_to_string ?graph_name:(g="G") bdd =
   (Hashtbl.fold (fun u node s ->
      s ^ (match node with
      | Node(a, low, high) ->
            Printf.sprintf "n%d [label=\"%s\"];\nn%d -> n%d [style=\"dashed\"];\nn%d -> n%d;\n"
            u (atom_to_string a) u low u high
      | Leaf lv -> Printf.sprintf "n%d [label=\"%s\" shape=box style=filled]
      {rank=sink; n%d};\n" u (leaf_value_to_string lv) u
      )
   )
   bdd.tbl (Printf.sprintf "digraph %s {\n" g)) ^ "}\n"

let print_bdd ?graph_name:(g="G") bdd = print_endline (bdd_to_string ~graph_name:g bdd)


(* This removes redundant predicates from the BDD. If the predicate of a node's
 * child is redundant, the child is replaced with either the child's low or
 * high branch. This is performed recursively until a non-redundant child is
 * encountered.
 *
 * TODO: don't just check immediate children for redundancy, but entire
 * subtree.
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
         | (Node(p2, ll, lh), _) when is_exp_subset p2 p -> 
               rm l;
               rm_tree lh;
               rep u (Node(p, ll, h));
               check_redundant u
         | (_, Node(p2, hl, hh)) when is_exp_subset p p2 -> 
               rm h;
               rm_tree hl;
               rep u (Node(p, l, hh));
               check_redundant u
         | (_, Node(p2, hl, hh)) when is_exp_disjoint p p2 -> 
               rm h;
               rm_tree hh;
               rep u (Node(p, l, hl));
               check_redundant u
         | (Node _, Node _) -> 
               check_redundant l; check_redundant h
         | (Leaf _, Leaf _) -> ()
         | _ -> ())
      | Leaf _ -> raise (Failure "This should never be applied to a leaf")
   in
   check_redundant bdd.root


let bdd_init (sorted_vars: atom list) =
   let bdd = {
      tbl = Hashtbl.create (int_exp 2 (List.length sorted_vars));
      root = 1;
      vars = sorted_vars;
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
   List.sort_uniq cmp_atoms
      (fold_atoms (fun acc a -> a::acc) [] t)

let rec bdd_insert bdd disj actions =
   let list_concat_uniq l1 l2 =
      l1 @ (List.filter (fun e -> not (List.mem e l1)) l2)
   in
   let rec add_conj u conj_list = match ((Hashtbl.find bdd.tbl u), conj_list) with 
   (* TODO: also check whether a var is a subset of another one. This is
    * because the tree has been reduced, so some variables are missing, which
    * means that they won't be consumed from the list as we descend
    *)
      | (Node(v, l, h), Not(Atom(x))::cl2) when v = x ->
            add_conj l cl2
      | (Node(v, l, h), Atom(x)::cl2) when v = x -> 
            add_conj h cl2
      | (Node(v, l, h), _) -> 
            add_conj l conj_list; add_conj h conj_list
      | (Leaf a, []) ->
            Hashtbl.replace bdd.tbl u (Leaf(list_concat_uniq a actions))
      | (Leaf a, _) -> () (* we reached a leaf, but didn't use all the vars *)
   in
   List.iter (fun c -> add_conj bdd.root c) (disj_to_list disj)

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
   let rm_redundant u node = match node with
      | Node(_, l, h) when l=h ->
            bdd_replace_node bdd u l; None
      | _ -> Some node
   in
   let rec repeat_reduce prev_len =
      bdd_remove_dupes bdd;
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


let main () =
   (*
   let (x, y, z) = (Atom(Ident("x")), Atom(Ident("y")), Atom(Ident("z"))) in
   let t =
      And(Or(x, Or(y, z)), And(Or(x, Or(Not(y), Not(z))), And(Or(y, Or(Not(x), Not(z))), Or(z, Or(Not(x), Not(y))))))
   in
   print_string "// ";
   print_form t;
   print_string "// ";
   print_form (to_dnf t);
*)
   let (a, b, c, d) = (
      Atom(Gt(Ident("p"), Number(10))),
      Atom(Gt(Ident("p"), Number(20))),
      Atom(Eq(Ident("s"), Ident("bar"))),
      Atom(Eq(Ident("s"), Ident("foo"))))
   in
   let t = And(a, And(b, And(c, d))) in
   let bdd = bdd_init (mk_var_list t) in
   bdd_insert bdd (And(a, c)) [1];
   bdd_insert bdd (And(b, c)) [2];
   bdd_insert bdd (d) [3];
   (*
   bdd_insert bdd (to_dnf t) [1];
   *)
   bdd_reduce bdd;
   print_bdd bdd;
   print_endline ""
;;

(*
main ()
*)

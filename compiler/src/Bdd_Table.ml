open Ast
open Formula
open Dnf
open Bdd

type field = expr

type node_id = int

type abstract_table_node =
   | MatchGroup of variable list * node_id
   | ActionGroup of action_list
   | Skip of node_id

type abstract_table = (node_id, abstract_table_node) Hashtbl.t

type table_name = string

type abstract_table_collection = {
   table_names: table_name list;
   fields: expr list;
   bdd: bdd_struct;
   tables: (table_name, abstract_table) Hashtbl.t;
}

let abstract_table_to_string ?graph_name:(g="G") atc =
   let rep a b = Str.global_replace (Str.regexp_string a) b in
   let escape s = rep "<" "&lt;" (rep ">" "&gt;" s) in
   let escape_quote s = rep "\"" "\\\"" s in
   let next_table_name tn =
      let rec _next = function
         | a::(b::l) -> if a=tn then b else _next (b::l)
         | a::[] -> "query_actions"
         | _ -> raise (Failure ("Couldn't find the successor table for " ^ tn))
      in
      _next atc.table_names
   in
   let matches_to_string ml =
      if (List.length ml)=0 then "*"
      else escape (String.concat ", " (List.map var_to_string ml))
   in
   (Printf.sprintf "digraph %s {\n" g) ^
   (bdd_to_string ~graph_name:"subgraph" atc.bdd ) ^
   "legend [shape=note style=filled label=\"" ^
   (List.fold_left (fun s r -> s ^ (match r with (t, lv) ->
      Printf.sprintf "%s: %s\\l"
                                    (escape_quote (formula_to_string t))
                                    (leaf_value_to_string lv))) "" atc.bdd.rules) ^

   "\"];\n" ^
   "subgraph {rank=same;\n" ^
   (Hashtbl.fold (fun field tbl s ->
      s ^ (Printf.sprintf
            "table_%s [shape=none margin=0 label=<
            <table cellpadding=\"3\" cellspacing=\"0\" border=\"0\" cellborder=\"1\">
            <tr><td colspan=\"3\"><b>%s</b></td></tr>
            <tr><td bgcolor=\"gray\">in</td><td bgcolor=\"gray\">match</td><td bgcolor=\"gray\">out</td></tr>" field field) ^
      (String.concat "|" (Hashtbl.fold (fun u n sl -> (match n with
            | MatchGroup(vl, dst) ->
               Printf.sprintf "<tr><td>%d</td><td>%s</td><td>%d</td></tr>" u (matches_to_string vl) dst
            | ActionGroup al -> Printf.sprintf "<tr><td>%d</td><td></td><td>%s</td></tr>" u (leaf_value_to_string al)
            | Skip dst -> Printf.sprintf "<tr><td>%d</td><td><i>skip</i></td><td>%d</td></tr>" u dst)::sl
      ) tbl [])) ^ "</table>>];\n"
   ) atc.tables "") ^
   (String.concat "" (List.map
         (fun t -> Printf.sprintf "table_%s -> table_%s;\n" t (next_table_name t))
         atc.table_names)) ^
   "}}\n"

let print_bdd_tables atc = print_endline (abstract_table_to_string atc)

let get_min_max range_preds =
   let nums = List.sort compare
      (List.map (fun p -> match p with
         | Lt(_, NumberLit i) | Gt(_, NumberLit i) | Eq(_, NumberLit i) -> i
         | _ -> raise (Failure ("Unexpected pred format: " ^ (var_to_string p)))
      )
      range_preds)
   in
   (List.hd nums, List.nth nums ((List.length nums) - 1))


let contains_eq matches =
   List.exists (fun p -> match p with
   | Eq(_,_) -> true | _ -> false) matches

let containts_lt matches =
   List.exists (fun p -> match p with
   | Lt(_,_) -> true | _ -> false) matches

let containts_gt matches =
   List.exists (fun p -> match p with
   | Gt(_,_) -> true | _ -> false) matches

let is_unbounded_range matches =
   let lt, gt = containts_lt matches, containts_gt matches in
   (lt && (not gt)) || (gt && (not lt))

let is_bounded_range matches =
   let lt, gt = containts_lt matches, containts_gt matches in
   lt && gt

let cmp_unbounded_range m1 m2 =
   let min1, max1 = get_min_max m1 in
   let min2, max2 = get_min_max m2 in
   match (containts_lt m1, containts_gt m1, containts_lt m2, containts_gt m2) with
   | (true, _, true, _) -> if (min min1 min2)=min1 then -1 else 1
   | (_, true, _, true) -> if (max max1 max2)=max1 then -1 else 1
   | _ -> 0 (* they are disjoint; order doesn't matter *)

let cmp_match_group ga gb = match (ga, gb) with
   | (MatchGroup([], _), MatchGroup([], _)) -> 0
   | (MatchGroup([], _), _) -> 1
   | (_, MatchGroup([], _)) -> -1
   | (MatchGroup(a, _), MatchGroup(b, _)) when contains_eq a && contains_eq b -> 0
   | (MatchGroup(a, _), MatchGroup(b, _)) when contains_eq a -> -1
   | (MatchGroup(a, _), MatchGroup(b, _)) when contains_eq b -> 1
   | (MatchGroup(a, _), MatchGroup(b, _)) when is_bounded_range a && is_bounded_range b -> 0
   | (MatchGroup(a, _), MatchGroup(b, _)) when is_unbounded_range a && is_unbounded_range b ->
         cmp_unbounded_range a b
   | (MatchGroup(a, _), MatchGroup(b, _)) when is_bounded_range a && is_unbounded_range b -> -1
   | (MatchGroup(a, _), MatchGroup(b, _)) when is_unbounded_range a && is_bounded_range b -> 1
   | _ -> raise (Failure "Unexpected types of matches")

let bdd_tables_create rules =
   let dnf_rules = List.map
      (fun r -> match r with Rule(Query e, a) -> (to_dnf (formula_of_query e), a))
      (List.rev rules)
   in
   let preds =
      mk_pred_list (List.fold_left
                     (fun conj x -> let t,_ = x in Formula.And(t, conj))
                     Empty dnf_rules)
   in
   let table_names = List.sort_uniq compare (List.map table_name_for_pred preds) in
   let bdd = bdd_init 1000 in
   List.iter (fun x -> match x with (t, a) -> bdd_add_query bdd t a) dnf_rules;
   let atc = {
      table_names = table_names;
      fields = List.sort_uniq cmp_fields (List.map field_for_pred bdd.vars);
      bdd = bdd;
      tables = Hashtbl.create ((List.length table_names) + 1);
   } in
   List.iter (fun t -> Hashtbl.add atc.tables t (Hashtbl.create 10)) table_names;
   let actions_table = Hashtbl.create 10 in
   Hashtbl.add atc.tables "query_actions" actions_table;
   let getn u = Hashtbl.find bdd.tbl u in
   (* XXX we re-number the root to state 0 here *)
   Hashtbl.add bdd.tbl 0 (getn bdd.root);
   Hashtbl.remove bdd.tbl bdd.root;
   bdd.root <- 0;
   let entry_nodes = Hashtbl.create 100 in
   let rec _visit u parent_table = match getn u with
      | Node(p, l, h) ->
            let t = table_name_for_pred p in
            if t <> parent_table then (
               if not (Hashtbl.mem entry_nodes u) then Hashtbl.add entry_nodes u t
            );
            _visit l t; _visit h t
      | Leaf _ -> ()
   in
   _visit bdd.root "";
   let rec follow_path current_tbl u matches = match getn u with
      | Node(p, l, h) when (table_name_for_pred p)=current_tbl ->
            (follow_path current_tbl l matches) @ (follow_path current_tbl h (p::matches))
      | Node _
      | Leaf _ ->
            [MatchGroup(matches, u)]
   in
   let find_matchgroups u current_tbl =
            let tbl = Hashtbl.find atc.tables current_tbl in
            assert (not (Hashtbl.mem tbl u));
            List.iter (Hashtbl.add tbl u)
               (List.sort cmp_match_group
                  (follow_path current_tbl u []))
   in
   Hashtbl.iter find_matchgroups entry_nodes;
   let add_leaf_nodes () = Hashtbl.iter (fun u n -> match n with
      | Leaf actions ->
            Hashtbl.add actions_table u (ActionGroup actions)
      | _ -> ())
      bdd.tbl
   in
   add_leaf_nodes ();
   atc


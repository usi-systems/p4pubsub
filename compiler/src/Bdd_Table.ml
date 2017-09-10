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
   bdd: bdd_struct;
   tables: (table_name, abstract_table) Hashtbl.t;
}

let abstract_table_to_string ?graph_name:(g="G") atc =
   let rep a b = Str.global_replace (Str.regexp_string a) b in
   let escape s = rep "<" "&lt;" (rep ">" "&gt;" s) in
   let next_table_name tn =
      let rec _next = function
         | a::(b::l) -> if a=tn then b else _next (b::l)
         | a::[] -> "__actions__"
         | _ -> raise (Failure ("Couldn't find the successor table for " ^ tn))
      in
      _next atc.table_names
   in
   let matches_to_string ml =
      if (List.length ml)=0 then "*"
      else escape (String.concat ", " (List.map var_to_string ml))
   in
   (Printf.sprintf "digraph %s {\n\n" g) ^
   (bdd_to_string ~graph_name:"subgraph" atc.bdd ) ^
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
   "}\n"

let print_bdd_tables atc = print_endline (abstract_table_to_string atc)

let bdd_tables_create rules =
   let dnf_rules = List.map
      (fun r -> match r with Rule(Query e, a) -> (to_dnf (formula_of_query e), a))
      (List.rev rules)
   in
   let preds =
      mk_var_list (List.fold_left
                     (fun conj x -> let t,_ = x in Formula.And(t, conj))
                     Empty dnf_rules)
   in
   let table_names = List.sort_uniq compare (List.map field_name_for_pred preds) in
   let next_table_name tn =
      let rec _next = function
         | a::(b::l) -> if a=tn then b else _next (b::l)
         | a::[] -> "__actions__"
         | _ -> raise (Failure ("Couldn't find the successor table for " ^ tn))
      in
      _next table_names
   in
   let bdd = bdd_init preds in
   List.iter (fun x -> match x with (t, a) -> bdd_insert bdd t a) dnf_rules;
   bdd_reduce bdd;
   let atc = {
      table_names = table_names;
      bdd = bdd;
      tables = Hashtbl.create ((List.length table_names) + 1);
   } in
   List.iter (fun t -> Hashtbl.add atc.tables t (Hashtbl.create 10)) table_names;
   let action_table = Hashtbl.create 10 in
   Hashtbl.add atc.tables "__actions__" action_table;
   let last_u = ref 0 in
   last_u := bdd.last_u;
   let get_new_u () = last_u := !last_u + 1; !last_u in
   let getn u = Hashtbl.find bdd.tbl u in
   let entry_nodes =
      let rec _visit u parent_table = match getn u with
         | Node(p, l, h) ->
               let t = field_name_for_pred p in
               (if t <> parent_table then [(t, u)] else []) @
                  (_visit l t) @ (_visit h t)
         | Leaf _ -> []
      in
      List.sort_uniq compare (_visit bdd.root "")
   in
   let rec follow_path current_tbl u matches = match getn u with
      | Node(p, l, h) when (field_name_for_pred p)=current_tbl ->
            (follow_path current_tbl l matches) @ (follow_path current_tbl h (p::matches))
      | Node _
      | Leaf _ ->
            [MatchGroup(matches, u)]
   in
   let find_matchgroups = function (current_tbl, u) -> 
            let tbl = Hashtbl.find atc.tables current_tbl in
            if not (Hashtbl.mem tbl u) then
               List.iter (Hashtbl.add tbl u)
                     (follow_path current_tbl u [])
   in
   List.iter find_matchgroups entry_nodes;
   let add_leaf_nodes () = Hashtbl.iter (fun u n -> match n with
      | Leaf actions ->
            Hashtbl.add action_table u (ActionGroup actions)
      | _ -> ())
      bdd.tbl
   in
   add_leaf_nodes ();
   let is_in_next_table u t =
      let tbl = Hashtbl.find atc.tables (next_table_name t) in
      Hashtbl.mem tbl u
   in
   let rec get_skip_node tbl t dst_u =
      Hashtbl.fold (fun u n found -> match found with
         | Some _ -> found
         | None -> (match n with
            | Skip dst_u2 when dst_u2=dst_u -> Some u
            | _ -> None
         )
      ) tbl None
   in
   let rec add_skip_node t dst_u =
      let tbl = Hashtbl.find atc.tables t in
      if Hashtbl.mem tbl dst_u then dst_u
      else (
         match get_skip_node tbl t dst_u with
            | Some existing_u -> existing_u
            | None -> 
               let new_u = get_new_u () in
               Hashtbl.add tbl new_u
                  (Skip (add_skip_node (next_table_name t) dst_u));
               new_u
      )
   in
   let add_skip_nodes () = List.iter (fun t -> 
         let tbl = Hashtbl.find atc.tables t in
         Hashtbl.filter_map_inplace (fun u n -> Some (match n with
            | MatchGroup(vl, dst_u) when not (is_in_next_table dst_u t) ->
                     MatchGroup(vl, add_skip_node (next_table_name t) dst_u)
            | _ -> n
            )
         ) tbl
      ) table_names
   in
   add_skip_nodes ();
   atc


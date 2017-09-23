open Ast
open Formula
open Dnf
open Bdd
open Bdd_Table


type p4_arg = int
type p4_action = string
type p4_table_name = string

type p4_match =
   | LtMatch of expr * int
   | GtMatch of expr * int
   | RangeMatch of expr * int * int
   | ExactIntMatch of expr * int
   | ExactStrMatch of expr * string

type p4_rule =
   | MatchAction of p4_table_name * p4_match list * p4_action * p4_arg list
   | DefaultAction of p4_table_name * p4_action * p4_arg list

type p4_mcast_group =
   McastGroup of int * int list

type p4_runtime_conf = {
   table_entries: p4_rule list;
   mcast_groups: p4_mcast_group list;
}

let get_field_from_preds preds = match preds with
   | ((Eq(f, _)) | (Lt(f, _)) | (Gt(f, _)))::_ -> f
         | _ -> raise (Failure "Unexpected pred format")

let is_exact_match pred = match pred with
   | Eq _ -> true
   | Lt _ | Gt _ -> false
   | _ -> raise (Failure "Unexpected predicate format")

let mk_single_match pred = match pred with
   | Eq(f, (NumberLit i | IpAddr i)) -> ExactIntMatch(f, i)
   | Eq(f, StringLit s) -> ExactStrMatch(f, s)
   | Lt(f, NumberLit i) -> LtMatch(f, i)
   | Gt(f, NumberLit i) -> GtMatch(f, i)
   (* TODO: generate rules for function calls *)
   | Eq(f, Call _) -> ExactIntMatch(f, 0)
   | Lt(f, Call _) -> LtMatch(f, 0)
   | Gt(f, Call _) -> GtMatch(f, 0)
   | _ -> raise (Failure ("Unexpected pred format: " ^ (var_to_string pred)))

let mk_range_match preds =
   let field = get_field_from_preds preds in
   let high, low = get_min_max preds in
   RangeMatch(field, low+1, high-1)

let preds_to_rule t preds meta_in meta_out =
   let meta_in = ExactIntMatch(Field(Some "meta", "state"), meta_in) in
   match preds with
      | p::[] when is_exact_match p ->
            MatchAction(t ^ "_exact", [meta_in; mk_single_match p], "set_next_state", [meta_out])
      | p::[] ->
            MatchAction(t ^ "_range", [meta_in; mk_single_match p], "set_next_state", [meta_out])
      | _::_ ->
            MatchAction(t ^ "_range", [meta_in; mk_range_match preds], "set_next_state", [meta_out])
      | [] ->
            MatchAction(t ^ "_miss", [meta_in], "set_next_state", [meta_out])

let fwd_action_to_rule last_mgid meta_in eg_ports =
   let meta_in = ExactIntMatch(Field(Some "meta", "state"), meta_in) in
   match eg_ports with
      | p::[] ->
            (MatchAction("tbl_actions", [meta_in], "set_egress_port", [p]), None)
      | _::_ ->
            let mgid = last_mgid + 1 in
            let grp = McastGroup(mgid, eg_ports) in
            (MatchAction("tbl_actions", [meta_in], "set_mgid", [mgid]), Some grp)
      | [] ->
            (MatchAction("tbl_actions", [meta_in], "_drop", []), None)

let matches_to_str ml =
   String.concat " " (List.map (fun m -> match m with
   | ExactIntMatch(_, i) -> string_of_int i
   | ExactStrMatch(_, s) -> s
   | RangeMatch(_, a, b) -> Printf.sprintf "%d->%d" a b
   | LtMatch(_, i) -> Printf.sprintf "<%d" i
   | GtMatch(_, i) -> Printf.sprintf ">%d" i
   ) ml)

let args_to_str args =
   String.concat " " (List.map string_of_int args)

let has_range_match ml =
   List.exists
   (fun m -> match m with RangeMatch _ | LtMatch _ | GtMatch _ -> true | _ -> false)
   ml

let dump_p4_runtime_commands rtc =
   String.concat "\n" (List.map (fun e -> match e with
      | MatchAction(t, ml, action, args) ->
         Printf.sprintf "table_add %s %s %s => %s%s"
            t action (matches_to_str ml) (args_to_str args)
            (if (has_range_match ml) then " 1" else "")
      | DefaultAction(t, action, args) ->
         Printf.sprintf "table_set_default %s %s => %s" t action (args_to_str args)
   ) rtc.table_entries)

let dump_p4_runtime_mcast_groups rtc =
   String.concat "\n" (List.map (fun g -> match g with McastGroup(mgid, ports) ->
      Printf.sprintf "%d: %s" mgid (args_to_str ports)
   ) rtc.mcast_groups)

let dump_p4_runtime_conf rtc =
   (dump_p4_runtime_commands rtc) ^
   "\n\n------------------\n  Mcast Groups\n------------------\n" ^
   (dump_p4_runtime_mcast_groups rtc) ^
   "\n\n------------------\n      Stats\n------------------\n" ^
   (Printf.sprintf "table_entries: %d\nmcast_groups: %d\n"
         (List.length rtc.table_entries) (List.length rtc.mcast_groups))

let print_p4_runtime_conf rtc = print_endline (dump_p4_runtime_conf rtc)

let create_p4_runtime_conf atc =
   let field_table_entries = Hashtbl.fold (fun table_name tbl l ->
         Hashtbl.fold (fun meta_in n l -> match n with
            | MatchGroup(preds, meta_out) ->
               (preds_to_rule table_name preds meta_in meta_out)::l
            | _ -> l
         ) tbl l
      ) atc.tables []
   in
   let (fwd_table_entries, mcast_grps) = Hashtbl.fold (fun table_name tbl (el, grps) ->
         Hashtbl.fold (fun meta_in n (el, grps) ->
            let last_mgid = (match grps with [] -> 0 | McastGroup(i, _)::_ -> i) in
            match n with
            | ActionGroup(ports) -> (match fwd_action_to_rule last_mgid meta_in ports with
               | (e, None) -> (e::el, grps)
               | (e, Some grp) -> (e::el, grp::grps)
            )
            | _ -> (el, grps)
         ) tbl (el, grps)
      ) atc.tables ([], [])
   in
   (* XXX Do we need any default entries? *)
   (*
   let default_table_entries = List.map (fun table_name ->
      DefaultAction(table_name, "default_set_next_state", [])

      ) atc.table_names
   in
   *)
   {
      table_entries = fwd_table_entries @ field_table_entries;
      mcast_groups = mcast_grps;
   }

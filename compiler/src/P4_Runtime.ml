open Ast
open Formula
open Dnf
open Bdd
open Bdd_Table


type p4_arg = int
type p4_action = string
type p4_table_name = string

type p4_match =
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

let mk_single_match pred = match pred with
   | Eq(f, (NumberLit i | IpAddr i)) -> ExactIntMatch(f, i)
   | Eq(f, StringLit s) -> ExactStrMatch(f, s)
   | Lt(f, NumberLit i) -> RangeMatch(f, 0, i-1)
   | Gt(f, NumberLit i) -> RangeMatch(f, i+1, max_int)
   | _ -> raise (Failure ("Unexpected pred format: " ^ (var_to_string pred)))

let mk_range_match preds =
   let field = get_field_from_preds preds in
   let high, low = get_min_max preds in
   RangeMatch(field, low+1, high-1)

let preds_to_rule t preds meta_in meta_out =
   let meta_in = ExactIntMatch(Field(Some "meta", "state"), meta_in) in
   match preds with
      | p::[] -> (* exact match *)
            MatchAction(t, [meta_in; mk_single_match p], "set_meta", [meta_out])
      | _::_ -> (* range match *)
            MatchAction(t, [meta_in; mk_range_match  preds], "set_meta", [meta_out])
      | [] -> (* default match *)
            MatchAction(t ^ "_miss", [meta_in], "set_meta", [meta_out])

let fwd_action_to_rule last_mgid meta_in out_ports =
   let meta_in = ExactIntMatch(Field(Some "meta", "state"), meta_in) in
   match out_ports with
      | p::[] ->
            (MatchAction("__fwd__", [meta_in], "set_out_port", [p]), None)
      | _::_ ->
            let mgid = last_mgid + 1 in
            let grp = McastGroup(mgid, out_ports) in
            (MatchAction("__fwd__", [meta_in], "set_mgid", [mgid]), Some grp)
      | [] ->
            (MatchAction("__fwd__", [meta_in], "drop_pkt", []), None)

let matches_to_str ml =
   String.concat " " (List.map (fun m -> match m with
   | ExactIntMatch(_, i) -> string_of_int i
   | ExactStrMatch(_, s) -> s
   | RangeMatch(_, a, b) -> Printf.sprintf "%d->%d" a b
   ) ml)

let args_to_str args =
   String.concat " " (List.map string_of_int args)

let has_range_match ml =
   List.exists (fun m -> match m with RangeMatch _ -> true | _ -> false) ml

let dump_p4_runtime_conf rtc =
   (String.concat "\n" (List.map (fun e -> match e with
      | MatchAction(t, ml, action, args) ->
         Printf.sprintf "table_add %s %s %s => %s%s"
            t action (matches_to_str ml) (args_to_str args)
            (if (has_range_match ml) then " 1" else "")
      | DefaultAction(t, action, args) ->
         Printf.sprintf "table_set_default %s %s => %s" t action (args_to_str args)
   ) rtc.table_entries)) ^
   "\n\n------------------\n  Mcast Groups\n------------------\n" ^
   (String.concat "\n" (List.map (fun g -> match g with McastGroup(mgid, ports) ->
      Printf.sprintf "%d -> [%s]" mgid (args_to_str ports)
   ) rtc.mcast_groups)) ^
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
   let default_table_entries = List.map (fun table_name ->
      DefaultAction(table_name, "default_set_meta", [])

      ) atc.table_names
   in
   {
      table_entries = default_table_entries @ fwd_table_entries @ field_table_entries;
      mcast_groups = mcast_grps;
   }

open Ast
open Formula
open Dnf
open Bdd
open Bdd_Table


type p4_field =
   P4Field of string * string (* header * field *)

let load_file f =
   let ic = open_in f in
   let n = in_channel_length ic in
   let s = Bytes.create n in
   really_input ic s 0 n;
   close_in ic;
   (s)

let string_of_field field = match field with
   | P4Field(h, f) -> h ^ "." ^ f

let header_of_field field = match field with
   | P4Field(h, f) -> h

let p4name_for_field field = match field with
   | P4Field(h, f) -> h ^ "_" ^ f

let make_tables field =
   let name = p4name_for_field field in
   let f = string_of_field field in
   Printf.sprintf "
table query_%s_exact {
    reads {
        camus_meta.state: exact;
        %s: exact;
    }
    actions {
        set_next_state;
        _nop;
    }
    size: 512;
}

table query_%s_range {
    reads {
        camus_meta.state: exact;
        %s: range;
    }
    actions {
        set_next_state;
        _nop;
    }
    size: 512;
}

table query_%s_miss {
    reads {
        camus_meta.state: exact;
    }
    actions {
        set_next_state;
        _nop;
    }
    size: 512;
}

" name f name f name

let make_control fields =
   let headers = List.sort_uniq compare (List.map header_of_field fields) in
   let valid_headers = String.concat "&&\n" (List.map (fun h -> "valid("^h^")") headers) in
   let make_apply field =
      let tbl = "query_" ^ (p4name_for_field field) in
      Printf.sprintf "
            apply(%s) {
               miss {
                  apply(%s) {
                     miss {
                        apply(%s);
                     }
                  }
               }
            }" (tbl ^ "_exact") (tbl ^ "_range") (tbl ^ "_miss")
   in
   let applies = String.concat "\n" (List.map make_apply fields) in
   Printf.sprintf "
        if (
           %s
        ) {
           %s
        }
   " valid_headers applies


let make_p4_fields fields =
   List.map (function
      | Field(Some h, f) -> P4Field(h, f)
      | Field(None, _) -> raise (Failure "A field must specify its header")
      | _ -> raise (Failure "Expected a Field")
   )
   fields

let generate_p4_program fields =
   let prog_tmpl = Scanf.format_from_string (load_file "router.p4.tmpl") "%s %s" in
   let tables = String.concat "\n" (List.map make_tables fields) in
   let control_block = make_control fields in
   Printf.sprintf prog_tmpl tables control_block


let main () =
   let fields = [P4Field("add_order", "price"); P4Field("add_order", "shares")] in
   let prog = generate_p4_program fields in
   print_endline prog

;;

open Core
open Lexer
open Lexing
open Parsing
open Ast
open Pretty
open Formula
open Dnf
open Bdd
open Bdd_Table
open P4_Runtime
open P4_Program

let save_to_file file s = Out_channel.write_all file ~data:s

let print_position outx lexbuf =
  let pos = lexbuf.lex_curr_p in
  fprintf outx "%s:%d:%d" pos.pos_fname
    pos.pos_lnum (pos.pos_cnum - pos.pos_bol + 1)

let parse_with_error lexbuf =
  try Parser.rule_list Lexer.main lexbuf
  with
  | SyntaxError msg ->
    fprintf stderr "%a: %s\n" print_position lexbuf msg;
    []
  | Parse_error ->  
    fprintf stderr "%a: syntax error\n" print_position lexbuf;
    exit (1)

let string_of_rules rl =
   List.fold_left rl ~init:"" ~f:(fun s r -> s ^ (Format.asprintf "%a\n" format_rule r))

let output_prog tables runtime_conf out_dir =
  if Sys.is_directory_exn out_dir then () else Unix.mkdir out_dir;
  (*
  (match Sys.is_directory out_dir with
  | No -> Unix.mkdir out_dir
  | _ -> ());
  *)
  save_to_file (Filename.concat out_dir "generated_commands.txt")
          (dump_p4_runtime_commands runtime_conf);
  save_to_file (Filename.concat out_dir "generated_mcast_groups.txt")
          (dump_p4_runtime_mcast_groups runtime_conf);
  save_to_file (Filename.concat out_dir "p4src/generated_router.p4")
          (generate_p4_program (make_p4_fields tables.fields));
          ()

let parse_rules_file filename =
  let inx = In_channel.create filename in
  let lexbuf = Lexing.from_channel inx in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
  let rules = parse_with_error lexbuf in
  In_channel.close inx;
  rules

let () =
  Command.basic ~summary:"Compile Camus Rules"
    Command.Spec.(
      empty
      +> flag "-t" (optional string) ~doc:"filename Path to P4 template file"
      +> flag "-o" (optional string) ~doc:"directory Output directory"
      +> flag "-p" no_arg ~doc:" Print the parsed rules and exit"
      +> flag "-v" (optional_with_default 1 int) ~doc:" Set verbosity level"
      +> anon ("filename" %: file)
    )
    (fun template_filename opt_out_dir parse_and_exit verbosity filename () ->
      let rules = parse_rules_file filename in
      match parse_and_exit with
      | true ->
          print_endline (string_of_rules rules)
      | false ->
          let tables = bdd_tables_create rules in
          if (verbosity > 0) then print_bdd_tables tables;
          begin
            match opt_out_dir with
            | Some out_dir ->
                let runtime_conf = create_p4_runtime_conf tables in
                output_prog tables runtime_conf out_dir
            | _ -> ()
          end
    )
  |> Command.run

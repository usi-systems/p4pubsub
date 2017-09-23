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

let create_and_print_bdd rules =
   let formulas =
      List.fold_left rules
         ~init:[]
         ~f:(fun l r -> (match r with Rule(Query(e), a) -> (to_dnf (formula_of_query e), a)::l))
   in
   let bdd = bdd_init 1000 in
   List.iter formulas (fun x -> match x with (t, a) -> bdd_add_query bdd t a);
   print_bdd bdd;
   ()

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

let parse_and_print lexbuf =
  let rules = parse_with_error lexbuf in
  let tables = bdd_tables_create rules in
  print_bdd_tables tables;
  let runtime_conf = create_p4_runtime_conf tables in
  print_endline ("/*\n" ^ (string_of_rules rules) ^ "*/\n");
  (*
  print_endline ("/*\n" ^ (dump_p4_runtime_conf runtime_conf) ^ "\n*/\n");
  *)
  save_to_file "generated_commands.txt" (dump_p4_runtime_commands runtime_conf);
  save_to_file "generated_mcast_groups.txt" (dump_p4_runtime_mcast_groups runtime_conf);
  save_to_file "p4src/generated_router.p4" (generate_p4_program (make_p4_fields tables.fields));
  ()


let loop filename () =
  let inx = In_channel.create filename in
  let lexbuf = Lexing.from_channel inx in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
  parse_and_print lexbuf;
  In_channel.close inx

let () =
  Command.basic ~summary:"Compile Camus Query"
    Command.Spec.(empty +> anon ("filename" %: file))
    loop 
  |> Command.run

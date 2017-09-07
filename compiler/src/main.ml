open Core
open Lexer
open Lexing
open Parsing
open Ast
open Pretty
open Formula
open Dnf
open Bdd

let create_and_print_bdd rules =
   let formulas =
      List.fold_left rules
         ~init:[]
         ~f:(fun l r -> (match r with Rule(Query(e), a) -> (to_dnf (formula_of_query e), a)::l))
   in
   let collect_vars acc x = match x with (t, _) -> Formula.And(t, acc) in
   let tmp_t = List.fold_left formulas ~init:Empty ~f:collect_vars in
   let bdd = bdd_init (mk_var_list tmp_t) in
   List.iter formulas (fun x -> match x with (t, a) -> bdd_insert bdd t a);
   bdd_reduce bdd;
   print_bdd bdd;
   ()

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
  create_and_print_bdd rules;
  print_endline ("/*\n" ^ (string_of_rules rules) ^ "*/\n")


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


open Core.Std
open Lexer
open Lexing
open Parsing
open Ast
open Pretty

let proceedings_required = ["author"; "title"; "pages"; "month"; "year"]
let article_required = ["author"; "title"; "pages"; "month"; "year"]
let misc_required = ["author"; "title"; "pages"; "month"; "year"]

let check_record r = 
  match r with 
  | RecordEntry(kind,key,ts) ->
    let required = match kind with
      | InProceedings -> proceedings_required 
      | Article -> article_required 
      | Misc -> misc_required 
      | _ -> []
    in
    let keys = List.fold_left ~f:(fun acc (Tag(k,_)) -> k::acc) ~init:[] ts in 
    List.for_all ~f:(fun i -> 
      let p =  List.mem keys i in 
      if not p then Printf.eprintf "%s missing %s\n" key i;
      true) required
  | _ -> assert false
  
let check_records rs = 
  List.fold_left ~f:(fun acc r -> acc && check_record r) ~init:true rs

let partition_entry (ss,ps,rs,cs) e = 
  match e with 
  | StringEntry(_) -> (e::ss, ps, rs, cs)
  | PreambleEntry(_) -> (ss, e::ps, rs, cs)
  | RecordEntry(_,_,_) -> (ss, ps, e::rs, cs)
  | CommentEntry(_) -> (ss, ps, rs, e::cs)

let partition_entries es = 
  List.fold_left ~f:(fun acc e -> partition_entry acc e) ~init:([],[],[],[]) es

let analyze ast = 
  let (Database(es)) = ast in 
  let (ss,ps,rs,cs) = partition_entries es in 
  let _ = check_records rs in 
  let rs' = List.sort (fun lhs rhs -> 
    match (lhs,rhs) with 
    | RecordEntry(_,k1,_), RecordEntry(_,k2,_) -> if k1 < k2 then 0 else 1
    | _ -> assert false
  ) rs in
  Database(ss@ps@rs'@cs)

let print_position outx lexbuf =
  let pos = lexbuf.lex_curr_p in
  fprintf outx "%s:%d:%d" pos.pos_fname
    pos.pos_lnum (pos.pos_cnum - pos.pos_bol + 1)

let parse_with_error lexbuf =
  try Parser.database Lexer.main lexbuf 
  with
  | SyntaxError msg ->
    fprintf stderr "%a: %s\n" print_position lexbuf msg;
    None
  | Parse_error ->  
    fprintf stderr "%a: syntax error\n" print_position lexbuf;
    exit (1)

let rec parse_and_print lexbuf =
  match parse_with_error lexbuf with
  | Some ast ->    
    let ast' = analyze ast in 
    Pretty.format ast';
    parse_and_print lexbuf
  | None -> () 

let loop filename () =
  let inx = In_channel.create filename in
  let lexbuf = Lexing.from_channel inx in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
  parse_and_print lexbuf;
  In_channel.close inx

let () =
  Command.basic ~summary:"Parse Bibtex"
    Command.Spec.(empty +> anon ("filename" %: file))
    loop 
  |> Command.run

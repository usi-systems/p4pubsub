{
  open Lexing
  open Parser
  open Ast


  exception SyntaxError of string

  let linenum =
    ref 1

  let set_linenum n =
    linenum := n

  let linestart =
    ref 0


  let info lexbuf =
    let c1 = Lexing.lexeme_start lexbuf in
    let c2 = Lexing.lexeme_end lexbuf in
    let l = !linenum in
    ((l, c1 - !linestart - 1),(l, c2 - !linestart - 1))

  let error lexbuf msg =	 
    (*
    let i = info lexbuf in
    let t = lexeme lexbuf in
    *)
    let s = "lexing error" in
    (* TODO: format error messages *)
    raise (SyntaxError s)

  let next_line lexbuf =
    let pos = lexbuf.lex_curr_p in
    lexbuf.lex_curr_p <-
      { pos with pos_bol = lexbuf.lex_curr_pos;
        pos_lnum = pos.pos_lnum + 1
      }

  let keywords = Hashtbl.create 53
  let _ =
    List.iter (fun (kwd, tok) -> Hashtbl.add keywords kwd tok)
      [ 
	("and", fun i -> AND i) 
        ; ("or", fun i -> OR i) 
        ; ("not", fun i -> NOT i)
      ]
    
}

let whitespace = [' ' '\t']+
let newline = "\n"
let id = ['a'-'z' 'A'-'Z' '_']['a'-'z' 'A'-'Z' '0'-'9' '_']*
let decimal = ['0'-'9']+
let float_ = ['0'-'9']+ '.' ['0'-'9']+
let hex = "0x" ['0'-'9' 'a'-'f' 'A'-'F']+
let int_char = ['0' - '9']
let hex_char = ['0' - '9' 'A' - 'F' 'a' - 'f']


rule main = 
  parse
  | whitespace         { main lexbuf }
  | "<"                { LT (info lexbuf) }	   
  | ">"                { GT (info lexbuf) }
  | "="                { EQ (info lexbuf) }
  | ":"                { COLON }
  | ","                { COMMA }
  | ";"                { SEMICOLON }
  | id as ident {
        try Hashtbl.find keywords ident (info lexbuf)
        with Not_found -> IDENT(info lexbuf, ident)
      }
  | decimal as integ {
        NUMBER(info lexbuf,int_of_string integ)
      }    
  | newline            { next_line lexbuf; main lexbuf  }  
  | eof                { EOF }
  | _                  { error lexbuf "unknown token" }




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

  let newline lexbuf =
    incr linenum;
    linestart := Lexing.lexeme_start lexbuf

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

  let int_of_hex = function
    | '0' -> 0 | '1' -> 1 | '2' -> 2 | '3' -> 3 | '4' -> 4
    | '5' -> 5 | '6' -> 6 | '7' -> 7 | '8' -> 8 | '9' -> 9
    | 'A' | 'a' -> 10 | 'B' | 'b' -> 11 | 'C' | 'c' -> 12
    | 'D' | 'd' -> 13 | 'E' | 'e' -> 14 | 'F' | 'f' -> 15
    | n -> failwith ("Lexer.int_of_hex: " ^ (String.make 1 n))

  let parse_byte str = Int64.of_string ("0x" ^ str)
  let parse_decbyte str = Int64.of_string str

}

let whitespace = [' ' '\t']+
let newline = "\n"
let id = ['a'-'z' 'A'-'Z' '_']['a'-'z' 'A'-'Z' '0'-'9' '_']*
let decimal = ['0'-'9']+
let float_ = ['0'-'9']+ '.' ['0'-'9']+
let hex = "0x" ['0'-'9' 'a'-'f' 'A'-'F']+
let int_char = ['0' - '9']
let string_lit = '"' [^'"']* '"'
let hex_char = ['0' - '9' 'A' - 'F' 'a' - 'f']
let decbyte =
     (['0'-'9'] ['0'-'9'] ['0'-'9']) | (['0'-'9'] ['0'-'9']) | ['0'-'9']

rule main =
  parse
  | whitespace         { main lexbuf }
  | "<"                { LT (info lexbuf) }
  | ">"                { GT (info lexbuf) }
  | "="                { EQ (info lexbuf) }
  | ":"                { COLON }
  | "."                { DOT }
  | ","                { COMMA }
  | ";"                { SEMICOLON }
  | "\""               {
                         let s = string_lit "" lexbuf in
                         STRING_LIT(info lexbuf,s)
                       }
  | id as ident {
        try Hashtbl.find keywords ident (info lexbuf)
        with Not_found -> IDENT(info lexbuf, ident)
      }
  | decimal as integ {
        NUMBER(info lexbuf,int_of_string integ)
      }

  | (decbyte as b4) "." (decbyte as b3) "." (decbyte as b2) "." (decbyte as b1)
          { let open Int64 in
            IPADDR(info lexbuf,
              (logor (shift_left (parse_decbyte b4) 24)
                 (logor (shift_left (parse_decbyte b3) 16)
                    (logor (shift_left (parse_decbyte b2) 8)
                       (parse_decbyte b1))))) }

  | newline            { next_line lexbuf; main lexbuf  }
  | eof                { EOF }
  | _                  { error lexbuf "unknown token" }

and escape el = parse
    | "\\"          { "\\" }
    | "b"           { "\008" }
    | "n"           { "\010" }
    | "r"           { "\013" }
    | "t"           { "\009" }
    | "0x" (hex_char as h1) (hex_char as h2) {
      String.make 1 (Char.chr (16 * int_of_hex h1 + int_of_hex h2))
    }

    | int_char int_char int_char as c {
      String.make 1 (Char.chr (int_of_string c))
    }
    | _ {
      try List.assoc (lexeme lexbuf) el
      with Not_found -> error lexbuf "in escape sequence"
    }

and string_lit acc = parse
    | "\\"          { let s = escape [("\"","\"");("'","'")] lexbuf in
                      string_lit (acc ^ s) lexbuf }
    | "\""          { acc }
    | newline ([' ' '\t']* "|")?
        { newline lexbuf; string_lit (acc ^ "\n") lexbuf}
    | eof           { error lexbuf "unmatched '\"'" }
    | _             { string_lit (acc ^ lexeme lexbuf) lexbuf }

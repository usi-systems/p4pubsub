{
  open Lexing
  open Parser

  exception SyntaxError of string

  let next_line lexbuf =
    let pos = lexbuf.lex_curr_p in
    lexbuf.lex_curr_p <-
      { pos with pos_bol = lexbuf.lex_curr_pos;
        pos_lnum = pos.pos_lnum + 1
      }

  let keyword_table = Hashtbl.create 53
  let _ =
    List.iter (fun (kwd, tok) -> Hashtbl.add keyword_table kwd tok)
      [ 
        "PREAMBLE", PREAMBLE; 
        "COMMENT", COMMENT;       
      ]

  let entry_unmatched = ref 0
  let value_unmatched = ref 0

  type context =
  | Comment
  | Entry

  let ctx = ref Comment
    
}

let whitespace = [' ' '\t']+
let digit = ['0'-'9']+
let newline = '\r' | '\n' | "\r\n"
let id = [^' ' '\t' '(' ')' '{' '}'  ',' '\"' '#' '%' '\'' '@' '\r' '\n' '=' ]+ 
let quoted =  '\"' ([^'"'] | '\\' '\"' )* '\"'
let inproceedings = ['i' 'I'] ['n' 'N']['p' 'P']['r' 'R']['o' 'O']['c' 'C']['e' 'E']['e' 'E']['d' 'D']['i' 'I']['n' 'N']['g' 'G']['s' 'S']
let article = ['a' 'A'] ['r' 'R']['t' 'T']['i' 'I']['c' 'C']['l' 'L']['e' 'E']
let misc = ['m' 'M'] ['i' 'I']['s' 's']['c' 'C']
let string = ['s' 'S'] ['t' 'T']['r' 'R']['i' 'I']['n' 'N']['g' 'G']
let preamble = ['p' 'P'] ['r' 'R']['e' 'E']['a' 'a']['m' 'M']['b' 'B']['l' 'L']['e' 'E']
let comment = ['c' 'C'] ['o' 'O']['m' 'M']['m' 'M']['e' 'E']['n' 'N']['t' 'T']


rule main = 
  parse
  | whitespace         { Printf.printf "got ws\n"; main lexbuf }
  | newline            { Printf.printf "got newline\n"; next_line lexbuf; main lexbuf  }  
  | quoted as q        { Printf.printf "got quoted\n"; match !ctx with | Entry -> Printf.printf "quoted =>%s<\n" q; QUOTED q | _ -> main lexbuf }
  | "{"                
      { 
        Printf.printf "got a {\n";
        match !ctx with
        | Entry ->  
          entry_unmatched := !entry_unmatched + 1;
          if !entry_unmatched > 1 then
            begin
              value_unmatched := !value_unmatched + 1; 
              let c = curlied (Lexing.lexeme lexbuf) lexbuf in
              Printf.printf "curlied = >%s<\n" c;
              CURLIED(c)
            end
          else
            LCURLY
        | Comment -> main lexbuf          
      }
  | "}"                
      { 
        Printf.printf "got a }\n";
        
        match !ctx with
        | Entry ->  
          entry_unmatched := !entry_unmatched - 1; 
          if !entry_unmatched == 0 then 
            begin
              ctx := Comment;
              RCURLY
            end
          else
            main lexbuf
        | Comment ->  main lexbuf 

      }
  | ","                { Printf.printf "got , \n"; match !ctx with | Entry -> COMMA | _ -> main lexbuf }
  | "#"                { Printf.printf "got # }\n";match !ctx with | Entry -> HASH | _ -> main lexbuf}
  | "@"                
      { 
        Printf.printf "got a @\n";
        match !ctx with
        | Entry -> assert false
        | Comment -> ctx := Entry; AT
      }
  | "="                
      { 
        Printf.printf "got a =\n";
        match !ctx with
        | Entry ->  
          Printf.printf "got a =, entry context\n";
          EQUALS
        | Comment -> main lexbuf 
      }

  | inproceedings      { match !ctx with | Entry -> Printf.printf "got INPROCEEDINGS\n"; INPROCEEDINGS | _ -> main lexbuf }
  | article            { match !ctx with | Entry -> ARTICLE | _ -> main lexbuf }
  | misc               { match !ctx with | Entry -> MISC | _ -> main lexbuf }
  | string             { match !ctx with | Entry -> Printf.printf "got STRING\n"; STRING | _ -> main lexbuf }
  | preamble           { match !ctx with | Entry -> PREAMBLE | _ -> main lexbuf }
  | comment            { match !ctx with | Entry -> COMMENT | _ -> main lexbuf }
  | id as name
   { 
     match !ctx with 
     | Entry ->  Printf.printf "got an id '%s'\n" name; NAME name 
     | _ -> main lexbuf
   }   
  | _                  {  
    Printf.printf "matched _\n";
    match !ctx with 
    | Entry -> raise (SyntaxError ("Unexpected char: " ^ Lexing.lexeme lexbuf)) 
    | Comment -> main lexbuf }
  | eof                {  Printf.printf "matched EOF\n"; EOF }


and curlied acc = parse
    | "}"  
        {          
          Printf.printf "in curlied }\n" ;
          value_unmatched := !value_unmatched - 1; 
          if !value_unmatched == 0 then 
            begin
              ctx := Entry;
              Printf.printf "got curlied acc = '%s'\n" acc;
              let l = lexeme lexbuf in 
              Printf.printf "got curlied l = '%s'\n" l;
              (acc ^ l)
            end
          else
            curlied (acc ^ lexeme lexbuf) lexbuf

        }
    |  "{" 
        {
          value_unmatched := !value_unmatched + 1; 
          curlied (acc ^ lexeme lexbuf) lexbuf
        }
    | eof
        { raise (SyntaxError "Unexpected EOF") }
    | _  
        {
          Printf.printf "in curlied _\n" ;
          curlied (acc ^ lexeme lexbuf) lexbuf
        }
        

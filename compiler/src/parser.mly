
%{

  open Ast
  open Globals

(*
# A rough grammar (case-insensitive):
#
# Database  ::= (Junk '@' Entry)*
# Junk      ::= .*?
# Entry ::= Record
#       |   Comment
#       |   String
#       |   Preamble
# Comment   ::= "comment" [^\n]* \n     -- ignored
# String    ::= "string" '{' Field* '}'
# Preamble  ::= "preamble" '{' .* '}'   -- (balanced)
# Record    ::= Type '{' Key ',' Field* '}'
#       |   Type '(' Key ',' Field* ')' -- not handled
# Type  ::= Name
# Key   ::= Name
# Field ::= Name '=' Value
# Name      ::= [^\s\"#%'(){}]*
# Value ::= [0-9]+
#       |   '"' ([^'"']|\\'"')* '"'
#       |   '{' .* '}'          -- (balanced)
  *)

%}

%token <string> NAME
%token <string> QUOTED
%token <string> CURLIED
%token <int> NUMBER
%token LCURLY
%token RCURLY 
%token COMMA 
%token HASH 
%token AT 
%token EQUALS 
%token EOF
%token STRING 
%token PREAMBLE
%token COMMENT
%token JUNK
%token INPROCEEDINGS
%token ARTICLE
%token MISC

%type <Ast.database option> database
%type <Ast.entry> entry
%type <Ast.entry> string
%type <Ast.entry> preamble
%type <Ast.entry> record
%type <Ast.etype> kind
%type <string> key
%type <Ast.tag> tag
%type <Ast.tags> tags
%type <Ast.content> content

%start database

%%

/* ----- Basic Grammar ----- */

database:
  | EOF { None }
  | statements { Some(Database($1)) } 


statements:
  | statement statements { $1::$2 }
  | { [] }

statement:
  | AT entry { $2 }

entry:
  | string             { $1 }
  | preamble           { $1 }
  | record             { $1 }
  | comment            { $1 }  

comment:
  | COMMENT NAME { CommentEntry($2) }

string:
  | STRING LCURLY tags RCURLY  { StringEntry($3) }

preamble: 
  | PREAMBLE LCURLY NAME RCURLY  { PreambleEntry($3) }

record:
  | kind LCURLY key COMMA tags RCURLY  { RecordEntry($1, $3, $5) }

kind:   
  | INPROCEEDINGS { InProceedings }
  | ARTICLE { Article }
  | MISC { Misc }
  | NAME  { Unknown($1) }

key:    
  | NAME  { $1 }

tags:
  | tag { [$1] }
  | tag COMMA tags { $1::$3 }

tag: 
  | NAME EQUALS content_expr  
      { 
        if (String.length $1 > !keylen) then keylen := String.length $1;
        Tag($1, $3) 
      }

content_expr:
  | content HASH content_expr {Concat($1,$3)}
  | content {$1}

content:
  | LCURLY content RCURLY  { Curlied($2) }
  | QUOTED { Quoted($1) }
  | NAME { Blob($1) }



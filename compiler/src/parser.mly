
%{
  open Ast
%}

%token <Ast.info * string option * string> FIELD
%token <Ast.info * string> STRING_LIT
%token <Ast.info * string> IDENT
%token <Ast.info * int> NUMBER
%token <Ast.info * Int64.t> IPADDR
%token <Ast.info> AND
%token <Ast.info> OR
%token <Ast.info> NOT
%token <Ast.info> ACTION
%token <Ast.info> LT
%token <Ast.info> GT
%token <Ast.info> EQ
%token EOF
%token DOT
%token COLON
%token COMMA
%token SEMICOLON
%token LPAREN RPAREN

%type <Ast.query> query
%type <Ast.rule> rule
%type <Ast.rule_list> rule_list
%type <Ast.action_list> action_list
%type <Ast.expr list> callArgs


%start rule_list

%%

/* ----- Basic Grammar ----- */

rule_list:
  | EOF { [] }
  | rule SEMICOLON rule_list { $1 :: $3 }

rule:
  | query COLON action_list { Rule($1, $3) }

action_list:
   | NUMBER { let _,n = $1 in [n] }
   | NUMBER COMMA action_list { let _,n = $1 in n :: $3 }

query:
  | logicOrExpr { Query($1) }

logicOrExpr:
  | logicAndExpr OR logicOrExpr { Or($1,$3) }
  | logicAndExpr { $1 }

logicAndExpr:
  | relExpr AND logicAndExpr { And($1,$3) }
  | relExpr { $1 }

relExpr:
  | primExpr LT relExpr { Lt($1,$3) }
  | primExpr GT relExpr { Gt($1,$3) }
  | primExpr EQ relExpr { Eq($1,$3) }
  | primExpr { $1 }

valExpr:
  | callExpr { $1 }
  | primExpr { $1 }

callArgs:
  | callArg { [$1] }
  | callArgs COMMA callArg { $3 :: $1 }

callArg:
  | valExpr { $1 }


primExpr:
  | STRING_LIT { let _,id = $1 in StringLit(id) }
  | IDENT DOT IDENT { let _,id1 = $1 and _,id2 = $3 in Field(Some id1, id2) }
  | IDENT { let _,id = $1 in Field(None, id) }
  | IPADDR { let _,id = $1 in IpAddr(Int64.to_int id) }
  | NUMBER { let _,id = $1 in NumberLit(id) }
  | callExpr { $1 }

callExpr:
  | IDENT LPAREN RPAREN { let _,id = $1 in Call(id, []) }
  | IDENT LPAREN callArgs RPAREN { let _,id = $1 in Call(id, List.rev $3) }


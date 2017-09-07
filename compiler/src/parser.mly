
%{
  open Ast
%}

%token <Ast.info * string> IDENT
%token< Ast.info * int> NUMBER
%token <Ast.info>  AND
%token <Ast.info>  OR
%token <Ast.info> NOT
%token <Ast.info> ACTION
%token <Ast.info> LT
%token <Ast.info> GT
%token <Ast.info> EQ
%token EOF
%token COLON
%token COMMA
%token SEMICOLON

%type <Ast.query> query
%type <Ast.rule> rule
%type <Ast.rule_list> rule_list
%type <Ast.action_list> action_list


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

primExpr:
  | IDENT { let _,id = $1 in Ident(id) }
  | NUMBER { let _,id = $1 in Number(id) }	


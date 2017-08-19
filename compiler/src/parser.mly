
%{
  open Ast
%}

%token <Ast.info * string> IDENT
%token< Ast.info * int> NUMBER
%token <Ast.info>  AND
%token <Ast.info>  OR
%token <Ast.info> NOT
%token <Ast.info> LT
%token <Ast.info> GT
%token <Ast.info> EQ
%token EOF

%type <Ast.query option> query


%start query

%%

/* ----- Basic Grammar ----- */

query:
  | EOF { None }
  | logicOrExpr { Some(Query($1)) } 

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


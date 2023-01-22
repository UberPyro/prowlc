%{
  open Batteries
  open Abstract.Syntax

  open Span
%}

%token
  REL PIPE /* type lang */

  LPAREN RPAREN
  LBRACK RBRACK
  LBRACE RBRACE

  COMMA SEMICOLON
  DEF SPEC
  EQ ARR BI
  KIND

  ASSIGN
  TYPE TAG

%token<string> 
  ID VAR
  STRING TAG /* expr lang */
  SLOW1 SLOW2
  MID1 MID2
  FAST

%token<int>
  STACK_VAR COSTACK_VAR /* type lang */
  INT /* expr lang */
%token<float> FLOAT
%token<char> CHAR

%%

value_type: _value_type {$1, make $loc}
%inline _value_type: 
  | ID {TId $1}
  | VAR {TVar $1}
  | LBRACK relation RBRACK {TQuote $2}
  | LBRACE relation RBRACE {TList $2}

%inline twin(x): separated_pair(x, REL, x) {$1}
%inline stack_head: nonempty_list(value_type) {$1}
%inline costack_head: 
  separated_nonempty_list(PIPE, pair(STACK_VAR, stack_head)) {$1}

relation: _relation {$1, make $loc}
%inline _relation: 
  | twin(stack_head) {ImplStack $1}
  | twin(costack_head) {ImplCostack $1}
  | twin(pair(COSTACK_VAR, costack_head)) {Expl $1}


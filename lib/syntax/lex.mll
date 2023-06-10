{
  open! Batteries
  open Lexing

  open Parse
}

let eol = ['\r' '\n'] | '\r' '\n'
let whitespace = ' '+

let digit = ['0'-'9']
let sig_digits = ['1'-'9'] digit*

let id_char = ['A'-'Z' 'a'-'z' '0'-'9' '_' '\'']
let id_tail = ('-'? id_char)*
let id = ['a'-'z'] id_tail
let cap_id = ['A'-'Z'] id_tail

let integer = '0' | sig_digits
let string_body = ([^ '"'] | "\\\"")*

rule token = parse
  | id as s     {VAR s}
  | "="         {ASSIGN}

  | "/*"        {comment 0 lexbuf}
  | eof         {EOF}
  | eol         {new_line lexbuf; token lexbuf}
  | whitespace  {token lexbuf}
  | '\t'        {token lexbuf}

  | "let"       {LET}
  | "in"        {IN}

  | "("         {LPAREN}
  | ")"         {RPAREN}
  | "["         {LBRACK}
  | "]"         {RBRACK}
  | "{"         {LBRACE}
  | "}"         {RBRACE}

  | "|"         {UNION}
  | "^?"        {MARK}
  | "^*"        {STAR}
  | "^+"        {PLUS}
  | "~"         {DAG}

  | "||"        {PICK}
  | "++"        {PONDER}
  | "&&"        {FORK}
  | "**"        {TENSOR}
  | "---"       {GUESS}
  | "==="       {CROSS}

  | ","         {COMMA}

  | (integer as i) {INT (int_of_string i)}
  | '"' (string_body as s) '"' {STRING s}

  | "+" {ADD} | "-" {SUB} | "*" {MUL}
  | "==" {EQ} | "!="{NEQ}
  | ">" {GT} | "<" "LT" | ">=" {GE} | "<=" {LE}
  | "<>" {CONTRA}
  | "gen" {GEN} | "fab" {FAB} | "exch" {EXCH} | "elim" {ELIM} | "cmp" {CMP}
  | "dup" {DUP} | "zap" {ZAP} | "swap" {SWAP}
  | "cons" {CONS} | "dip" {DIP} | "cat" {CAT} | "unit" {UNIT}
  | "divmod" {DIVMOD} | "lin" {LIN} | "bin" {BIN}
  | "parse" {PARSE} | "show" {SHOW}
  | "nop" {NOP} | "id" {ID} | "ab" {AB}

and comment level = parse
  | "*/" {if level = 0 then token lexbuf
          else comment (level-1) lexbuf}
  | "/*" {comment (level+1) lexbuf}
  | _    {comment level lexbuf}
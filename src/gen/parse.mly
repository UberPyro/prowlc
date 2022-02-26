%{ open Batteries
   
   open Ast
   open Parse_proc %}

%token
  FN VAL LET IN REC
  OPEN INCL SPEC INST IMP
  PUB OPAQ TYPE
  NEW DATA
  MOD SIG BEGIN END
  TO WITH PAT DOT

  PLUS MINUS TIMES DIV ASSIGN

  CMP EQ NEQ
  SLT SGT SLE SGE

  AND OR

  CONS SNOC DOLLAR AT PERCENT CARET
  FOLDL FOLDR QMARK EMARK PIPE AMPERSAND

  LANGLE RANGLE
  LPAREN RPAREN
  LBRACKET RBRACKET
  LBRACE RBRACE PBRACE

  COMMA COLON ARROW BACKARROW

  UNIT NOP QNOP BLANK EOF

%token<string>
  ID CAP_ID MOD_ID PMOD_ID MACRO_ID
  VARIANT PVARIANT STRING
  METATYPE LABEL

%token<int> INTEGER
%token<float> FLOAT
%token<char> CHAR

%left CMP
%left EQ NEQ
%left OR PIPE
%left AND AMPERSAND
%right CONS
%left SNOC
%left PLUS MINUS
%left TIMES DIV

%right ARROW

%nonassoc MOD_ID PMOD_ID MACRO_ID

%start<stmt> program

%%

program: stmt EOF                                                       {$1}

spec: 
  | SPEC any_id COLON ty                                     {Spec ($2, $4)}
  | TYPE any_id ASSIGN ty                                   {SType ($2, $4)}
  | TYPE any_id                                                  {SAbsTy $2}
  | DATA any_id ASSIGN data                                 {SData ($2, $4)}

ty: 
  | pair(terminated(separated_nonempty_list(COMMA, 
    type_constraint), IN), ty_body)                                     {$1}
  | ty_body                                                         {[], $1}

%inline type_constraint: pair(any_id, nonempty_list(any_id))            {$1}

ty_body: 
  | any_id                                                          {TId $1}
  | ty_body ARROW ty_body                                     {TFn ($1, $3)}
  | UNIT                                                             {TUnit}
  | METATYPE                                                  {SMetaType $1}
  | nonempty_list(ty_term)                                          {TSq $1}
  | to_like(WITH, ty)                                             {TWith $1}

ty_term: 
  | arr_like(ty_body)                                              {TArr $1}
  | grouped(ty_body)                                                    {$1}
  | quoted(ty_body)                                             {TQuoted $1}
  | mod_like(SIG, spec)                                             {Sig $1}

data: 
  | arr_like(pair(opt_unit(ty), VARIANT))                      {DVariant $1}
  | record_like(ID, ty)                                         {DRecord $1}
  | record_like(CAP_ID, ty)                                 {DPolyRecord $1}

%inline opt_unit(t): ioption(t)                      { match $1 with
                                                       | Some s -> s
                                                       | None -> [], TUnit }

stmt: 
  | ioption(annot) ioption(pub) ioption(imp_mods) ioption(rec_)
    FN pat list(named_arg) any_id ASSIGN expr
                          {Fn (filter_id [$1; $2; $3; $4], $6, $7, $8, $10)}
  | ioption(annot) ioption(pub) ioption(imp_mods) ioption(rec_)
      VAL pat ASSIGN expr         {Val (filter_id [$1; $2; $3; $4], $6, $8)}
  | OPEN expr                                                      {Open $2}
  | INCL ioption(inst) expr                      {Incl (filter_id [$2], $3)}
  | IMP expr                                                        {Imp $2}
  | ioption(access_mods) ioption(imp) ioption(new_) TYPE any_id ASSIGN ty
                                       {Ty (filter_id [$1; $2; $3], $5, $7)}
  | TYPE any_id                                                   {AbsTy $2}
  | ioption(access_mods) ioption(imp) DATA any_id ASSIGN data
                                         {Data (filter_id [$1; $2], $4, $6)}
  | mod_like(BEGIN, stmt)                                         {Begin $1}

%inline new_: NEW                                                     {`New}
%inline inst: INST                                                   {`Inst}
%inline imp: IMP                                                      {`Imp}
%inline pub: PUB                                                      {`Pub}
%inline rec_: REC                                                     {`Rec}

%inline imp_mods: 
  | IMP                                                               {`Imp}
  | INST                                                             {`Inst}

%inline access_mods: 
  | PUB                                                               {`Pub}
  | OPAQ                                                             {`Opaq}

%inline annot: SPEC ty                                      {`Annotation $2}

%inline any_id:
  | ID                                                                  {$1}
  | CAP_ID                                                              {$1}

%inline named_arg: 
  pair(LABEL, ioption(grouped(expr)))                                   {$1}

expr: 
  | any_id                                                           {Id $1}
  | MOD_ID expr                                            {Spaced ($1, $2)}
  | PMOD_ID expr                                          {PSpaced ($1, $2)}
  | MACRO_ID expr                                           {Macro ($1, $2)}
  | to_like(TO, ty)                                                  {To $1}
  | to_like(WITH, ty)                                              {With $1}
  | METATYPE                                                   {Metatype $1}
  | VARIANT                                                     {Variant $1}
  | PVARIANT                                                {PolyVariant $1}

  | STRING                                                       {StrLit $1}
  | CHAR                                                        {CharLit $1}
  | INTEGER                                                      {IntLit $1}
  | FLOAT                                                      {FloatLit $1}
  | UNIT                                                           {UnitLit}
  | NOP                                                         {FuncLit []}
  | QNOP                                               {Quoted (FuncLit [])}

  | DOLLAR                                                            {Lift}
  | AT                                                               {LiftA}
  | PERCENT                                                          {LiftM}
  | CARET                                                             {Fold}
  | FOLDL                                                            {FoldL}
  | FOLDR                                                            {FoldR}
  | QMARK                                                        {FilterMap}
  | EMARK                                                              {Dup}
  | BACKARROW                                                          {Mut}

  | expr bop expr                                         {Bop ($1, $2, $3)}
  | nonempty_list(term)                                              {Sq $1}

term: 
  | grouped(bop)                                                   {Sect $1}
  | grouped(pair(bop, expr))                 {let b, e = $1 in SectL (b, e)}
  | grouped(pair(expr, bop))                 {let e, b = $1 in SectR (e, b)}
  | cmp_op                                                      {SectCmp $1}

  | delimited(LET, stmt, IN)                                        {Let $1}
  | mod_like(MOD, stmt)                                             {Mod $1}
  | record_like(ID, expr)                                        {Record $1}
  | record_like(CAP_ID, expr)                                {PolyRecord $1}
  | tuple_like(expr)                                              {Tuple $1}

  | arr_like(expr)                                             {ArrayLit $1}
  | func_like(pat, expr)                                        {FuncLit $1}
  | quoted(expr)                                                 {Quoted $1}
  | grouped(expr)                                                       {$1}

%inline func_like(key, value): delimited(
    LBRACE, 
    separated_list(COMMA, separated_pair(key, ARROW, value)), 
  RBRACE)                                                               {$1}

%inline record_like(key, value): delimited(
    PBRACE, 
    separated_nonempty_list(COMMA, separated_pair(key, ARROW, value)), 
  RBRACE)                                                               {$1}

%inline arr_like(elem): 
  delimited(LBRACKET, separated_list(COMMA, elem), RBRACKET)            {$1}

%inline tuple_like(elem): 
  grouped(separated_pair(elem, COMMA, 
  separated_nonempty_list(COMMA, elem)))           {let h, t = $1 in h :: t}

%inline mod_like(open_kw, s): delimited(open_kw, list(s), END)          {$1}

%inline to_like(kw, content): preceded(kw, grouped(content))            {$1}

%inline grouped(expr_like): delimited(LPAREN, expr_like, RPAREN)        {$1}
%inline quoted(expr_like): delimited(LANGLE, expr_like, RANGLE)         {$1}

%inline bop: 
  | PLUS                                                               {Add}
  | MINUS                                                              {Sub}
  | TIMES                                                              {Mul}
  | DIV                                                                {Div}
  | AND                                                                {And}
  | OR                                                                  {Or}

  | EQ                                                                  {Eq}
  | NEQ                                                                {Neq}
  | CMP                                                                {Cmp}

  | CONS                                                              {Cons}
  | SNOC                                                              {Snoc}

%inline cmp_op: 
  | SLT                                                                 {Lt}
  | SGT                                                                 {Gt}
  | SLE                                                                 {Le}
  | SGE                                                                 {Ge}

pat: 
  | pair(pat_body, pat_constraint)                                      {$1}
  | pat_body                                                        {$1, []}

%inline pat_constraint: 
  preceded(DOT, separated_nonempty_list(COMMA, expr))                   {$1}

pat_body: 
  | any_id                                                          {PId $1}
  | BLANK                                                         {WildCard}
  | pat_body pbop pat_body                               {PBop ($1, $2, $3)}
  | pcmp_op                                                        {PCmp $1}
  | to_like(PAT, expr)                                          {PActive $1}

  | INTEGER                                                      {IntPat $1}
  | FLOAT                                                      {FloatPat $1}
  | CHAR                                                        {CharPat $1}
  | STRING                                                       {StrPat $1}
  | UNIT                                                           {UnitPat}
  | VARIANT                                                    {PVariant $1}
  | PVARIANT                                               {PPolyVariant $1}

  | nonempty_list(pat_term)                                         {PSq $1}

pat_term:
  | tuple_like(pat_body)                                         {PTuple $1}
  | record_like(ID, pat_body)                                   {PRecord $1}
  | record_like(CAP_ID, pat_body)                           {PPolyRecord $1}
  | arr_like(pat_body)                                             {PArr $1}
  | func_like(expr, pat_body)                                     {PDict $1}
  | grouped(pat_body)                                                   {$1}
  | quoted(pat_body)                                            {PQuoted $1}

%inline pbop: 
  | CONS                                                             {PCons}
  | SNOC                                                             {PSnoc}
  | PIPE                                                               {POr}
  | AMPERSAND                                                         {PAnd}

%inline pcmp_op: 
  | SLT                                                                {PLt}
  | SGT                                                                {PGt}
  | SLE                                                                {PLe}
  | SGE                                                                {PGe}
  | grouped(EQ)                                                        {PEq}
  | grouped(NEQ)                                                      {PNeq}

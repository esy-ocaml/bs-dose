type token =
  | IDENT of (string)
  | LPAREN
  | RPAREN
  | COMMA
  | REGEXP of (string)
  | EXACT of (string)
  | PLUS
  | MINUS
  | EOL
  | COUNT
  | SUM
  | UNSATREC
  | ALIGNED
  | NOTUPTODATE
  | SOLUTION
  | CHANGED
  | NEW
  | REMOVED
  | UP
  | DOWN

open Parsing;;
let _ = parse_error;;
# 2 "common/criteria_parser.mly"

(* 
ASPCUD accepted criteria

      Default: none
      Valid:   none, paranoid, -|+<crit>(,-|+<crit>)*
        <crit>: count(<set>) | sum(<set>,<attr>) | unsat_recommends(<set>)
              | aligned(<set>,<attr>,<attr>) | notuptodate(<set>)
        <attr>: CUDF attribute name
        <set> : solution | changed | new | removed | up | down
      For backwards compatibility: 
        new              = count(new)
        removed          = count(removed)
        changed          = count(changed)
        notuptodate      = notuptodate(solution)
        unsat_recommends = unsat_recommends(solution)
        sum(name)        = sum(name,solution)
*)
open Criteria_types

# 47 "common/criteria_parser.ml"
let yytransl_const = [|
  258 (* LPAREN *);
  259 (* RPAREN *);
  260 (* COMMA *);
  263 (* PLUS *);
  264 (* MINUS *);
  265 (* EOL *);
  266 (* COUNT *);
  267 (* SUM *);
  268 (* UNSATREC *);
  269 (* ALIGNED *);
  270 (* NOTUPTODATE *);
  271 (* SOLUTION *);
  272 (* CHANGED *);
  273 (* NEW *);
  274 (* REMOVED *);
  275 (* UP *);
  276 (* DOWN *);
    0|]

let yytransl_block = [|
  257 (* IDENT *);
  261 (* REGEXP *);
  262 (* EXACT *);
    0|]

let yylhs = "\255\255\
\001\000\002\000\002\000\003\000\003\000\004\000\004\000\004\000\
\004\000\004\000\004\000\004\000\004\000\004\000\004\000\004\000\
\007\000\005\000\005\000\005\000\005\000\005\000\005\000\006\000\
\006\000\000\000"

let yylen = "\002\000\
\002\000\001\000\003\000\002\000\002\000\004\000\006\000\006\000\
\004\000\001\000\008\000\004\000\001\000\001\000\001\000\001\000\
\001\000\001\000\001\000\001\000\001\000\001\000\001\000\002\000\
\002\000\002\000"

let yydefred = "\000\000\
\000\000\000\000\000\000\000\000\026\000\000\000\000\000\000\000\
\000\000\000\000\000\000\000\000\016\000\014\000\015\000\004\000\
\005\000\001\000\000\000\000\000\000\000\000\000\000\000\000\000\
\003\000\018\000\019\000\020\000\021\000\022\000\023\000\000\000\
\000\000\000\000\000\000\000\000\006\000\000\000\000\000\009\000\
\000\000\012\000\000\000\000\000\017\000\000\000\000\000\025\000\
\024\000\007\000\008\000\000\000\000\000\011\000"

let yydgoto = "\002\000\
\005\000\006\000\007\000\016\000\032\000\044\000\046\000"

let yysindex = "\005\000\
\013\255\000\000\247\254\247\254\000\000\001\255\018\255\029\255\
\032\255\033\255\034\255\035\255\000\000\000\000\000\000\000\000\
\000\000\000\000\013\255\253\254\253\254\253\254\253\254\253\254\
\000\000\000\000\000\000\000\000\000\000\000\000\000\000\026\255\
\036\255\038\255\039\255\041\255\000\000\037\255\044\255\000\000\
\044\255\000\000\027\255\043\255\000\000\045\255\046\255\000\000\
\000\000\000\000\000\000\044\255\048\255\000\000"

let yyrindex = "\000\000\
\000\000\000\000\000\000\000\000\000\000\000\000\030\255\000\000\
\000\000\014\255\000\000\015\255\000\000\000\000\000\000\000\000\
\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\000\000\000\000\000\000\000\000\000\000\000\000"

let yygindex = "\000\000\
\000\000\023\000\000\000\043\000\004\000\000\000\215\255"

let yytablesize = 51
let yytable = "\047\000\
\008\000\009\000\010\000\011\000\012\000\001\000\013\000\014\000\
\015\000\018\000\053\000\026\000\027\000\028\000\029\000\030\000\
\031\000\010\000\013\000\003\000\004\000\019\000\010\000\013\000\
\033\000\034\000\035\000\036\000\037\000\038\000\020\000\048\000\
\049\000\021\000\022\000\023\000\024\000\043\000\002\000\039\000\
\040\000\025\000\041\000\042\000\045\000\050\000\017\000\051\000\
\000\000\052\000\054\000"

let yycheck = "\041\000\
\010\001\011\001\012\001\013\001\014\001\001\000\016\001\017\001\
\018\001\009\001\052\000\015\001\016\001\017\001\018\001\019\001\
\020\001\004\001\004\001\007\001\008\001\004\001\009\001\009\001\
\021\000\022\000\023\000\024\000\003\001\004\001\002\001\005\001\
\006\001\002\001\002\001\002\001\002\001\001\001\009\001\004\001\
\003\001\019\000\004\001\003\001\001\001\003\001\004\000\003\001\
\255\255\004\001\003\001"

let yynames_const = "\
  LPAREN\000\
  RPAREN\000\
  COMMA\000\
  PLUS\000\
  MINUS\000\
  EOL\000\
  COUNT\000\
  SUM\000\
  UNSATREC\000\
  ALIGNED\000\
  NOTUPTODATE\000\
  SOLUTION\000\
  CHANGED\000\
  NEW\000\
  REMOVED\000\
  UP\000\
  DOWN\000\
  "

let yynames_block = "\
  IDENT\000\
  REGEXP\000\
  EXACT\000\
  "

let yyact = [|
  (fun _ -> failwith "parser")
; (fun __caml_parser_env ->
    let _1 = (Parsing.peek_val __caml_parser_env 1 : 'criteria) in
    Obj.repr(
# 40 "common/criteria_parser.mly"
                           ( _1 )
# 171 "common/criteria_parser.ml"
               : Criteria_types.criteria))
; (fun __caml_parser_env ->
    let _1 = (Parsing.peek_val __caml_parser_env 0 : 'predicate) in
    Obj.repr(
# 43 "common/criteria_parser.mly"
              ( [_1] )
# 178 "common/criteria_parser.ml"
               : 'criteria))
; (fun __caml_parser_env ->
    let _1 = (Parsing.peek_val __caml_parser_env 2 : 'predicate) in
    let _3 = (Parsing.peek_val __caml_parser_env 0 : 'criteria) in
    Obj.repr(
# 44 "common/criteria_parser.mly"
                             ( _1 :: _3 )
# 186 "common/criteria_parser.ml"
               : 'criteria))
; (fun __caml_parser_env ->
    let _2 = (Parsing.peek_val __caml_parser_env 0 : 'crit) in
    Obj.repr(
# 47 "common/criteria_parser.mly"
              ( Maximize(_2) )
# 193 "common/criteria_parser.ml"
               : 'predicate))
; (fun __caml_parser_env ->
    let _2 = (Parsing.peek_val __caml_parser_env 0 : 'crit) in
    Obj.repr(
# 48 "common/criteria_parser.mly"
               ( Minimize(_2) )
# 200 "common/criteria_parser.ml"
               : 'predicate))
; (fun __caml_parser_env ->
    let _3 = (Parsing.peek_val __caml_parser_env 1 : 'set) in
    Obj.repr(
# 51 "common/criteria_parser.mly"
                            ( Count(_3,None) )
# 207 "common/criteria_parser.ml"
               : 'crit))
; (fun __caml_parser_env ->
    let _3 = (Parsing.peek_val __caml_parser_env 3 : 'set) in
    let _5 = (Parsing.peek_val __caml_parser_env 1 : 'field) in
    Obj.repr(
# 52 "common/criteria_parser.mly"
                                        ( Count(_3,Some _5) )
# 215 "common/criteria_parser.ml"
               : 'crit))
; (fun __caml_parser_env ->
    let _3 = (Parsing.peek_val __caml_parser_env 3 : 'set) in
    let _5 = (Parsing.peek_val __caml_parser_env 1 : 'attr) in
    Obj.repr(
# 53 "common/criteria_parser.mly"
                                     ( Sum(_3,_5) )
# 223 "common/criteria_parser.ml"
               : 'crit))
; (fun __caml_parser_env ->
    let _3 = (Parsing.peek_val __caml_parser_env 1 : 'set) in
    Obj.repr(
# 54 "common/criteria_parser.mly"
                               ( Unsatrec(_3) )
# 230 "common/criteria_parser.ml"
               : 'crit))
; (fun __caml_parser_env ->
    Obj.repr(
# 55 "common/criteria_parser.mly"
             ( Unsatrec(Solution) )
# 236 "common/criteria_parser.ml"
               : 'crit))
; (fun __caml_parser_env ->
    let _3 = (Parsing.peek_val __caml_parser_env 5 : 'set) in
    let _5 = (Parsing.peek_val __caml_parser_env 3 : 'attr) in
    let _7 = (Parsing.peek_val __caml_parser_env 1 : 'attr) in
    Obj.repr(
# 56 "common/criteria_parser.mly"
                                                    ( Aligned(_3,_5,_7) )
# 245 "common/criteria_parser.ml"
               : 'crit))
; (fun __caml_parser_env ->
    let _3 = (Parsing.peek_val __caml_parser_env 1 : 'set) in
    Obj.repr(
# 57 "common/criteria_parser.mly"
                                  ( NotUptodate(_3) )
# 252 "common/criteria_parser.ml"
               : 'crit))
; (fun __caml_parser_env ->
    Obj.repr(
# 58 "common/criteria_parser.mly"
                ( NotUptodate(Solution) )
# 258 "common/criteria_parser.ml"
               : 'crit))
; (fun __caml_parser_env ->
    Obj.repr(
# 59 "common/criteria_parser.mly"
        ( Count(New,None) )
# 264 "common/criteria_parser.ml"
               : 'crit))
; (fun __caml_parser_env ->
    Obj.repr(
# 60 "common/criteria_parser.mly"
            ( Count(Removed,None) )
# 270 "common/criteria_parser.ml"
               : 'crit))
; (fun __caml_parser_env ->
    Obj.repr(
# 61 "common/criteria_parser.mly"
            ( Count(Changed,None) )
# 276 "common/criteria_parser.ml"
               : 'crit))
; (fun __caml_parser_env ->
    let _1 = (Parsing.peek_val __caml_parser_env 0 : string) in
    Obj.repr(
# 63 "common/criteria_parser.mly"
            ( _1 )
# 283 "common/criteria_parser.ml"
               : 'attr))
; (fun __caml_parser_env ->
    Obj.repr(
# 66 "common/criteria_parser.mly"
             ( Solution )
# 289 "common/criteria_parser.ml"
               : 'set))
; (fun __caml_parser_env ->
    Obj.repr(
# 67 "common/criteria_parser.mly"
            ( Changed )
# 295 "common/criteria_parser.ml"
               : 'set))
; (fun __caml_parser_env ->
    Obj.repr(
# 68 "common/criteria_parser.mly"
        ( New )
# 301 "common/criteria_parser.ml"
               : 'set))
; (fun __caml_parser_env ->
    Obj.repr(
# 69 "common/criteria_parser.mly"
            ( Removed )
# 307 "common/criteria_parser.ml"
               : 'set))
; (fun __caml_parser_env ->
    Obj.repr(
# 70 "common/criteria_parser.mly"
       ( Up )
# 313 "common/criteria_parser.ml"
               : 'set))
; (fun __caml_parser_env ->
    Obj.repr(
# 71 "common/criteria_parser.mly"
         ( Down )
# 319 "common/criteria_parser.ml"
               : 'set))
; (fun __caml_parser_env ->
    let _1 = (Parsing.peek_val __caml_parser_env 1 : string) in
    let _2 = (Parsing.peek_val __caml_parser_env 0 : string) in
    Obj.repr(
# 74 "common/criteria_parser.mly"
                ( (_1,ExactMatch(_2)) )
# 327 "common/criteria_parser.ml"
               : 'field))
; (fun __caml_parser_env ->
    let _1 = (Parsing.peek_val __caml_parser_env 1 : string) in
    let _2 = (Parsing.peek_val __caml_parser_env 0 : string) in
    Obj.repr(
# 75 "common/criteria_parser.mly"
                 ( (_1,Regexp(_2)) )
# 335 "common/criteria_parser.ml"
               : 'field))
(* Entry criteria_top *)
; (fun __caml_parser_env -> raise (Parsing.YYexit (Parsing.peek_val __caml_parser_env 0)))
|]
let yytables =
  { Parsing.actions=yyact;
    Parsing.transl_const=yytransl_const;
    Parsing.transl_block=yytransl_block;
    Parsing.lhs=yylhs;
    Parsing.len=yylen;
    Parsing.defred=yydefred;
    Parsing.dgoto=yydgoto;
    Parsing.sindex=yysindex;
    Parsing.rindex=yyrindex;
    Parsing.gindex=yygindex;
    Parsing.tablesize=yytablesize;
    Parsing.table=yytable;
    Parsing.check=yycheck;
    Parsing.error_function=parse_error;
    Parsing.names_const=yynames_const;
    Parsing.names_block=yynames_block }
let criteria_top (lexfun : Lexing.lexbuf -> token) (lexbuf : Lexing.lexbuf) =
   (Parsing.yyparse yytables 1 lexfun lexbuf : Criteria_types.criteria)
;;
# 78 "common/criteria_parser.mly"

let criteria_top = Format822.error_wrapper "criteria" criteria_top
# 363 "common/criteria_parser.ml"

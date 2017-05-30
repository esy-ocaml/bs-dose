# 13 "common/shell_lexer.mll"
 
  exception UnknownShellEscape of string
  exception UnmatchedChar of char
  let buf_from_str str =
    let buf = Buffer.create 16 in
    Buffer.add_string buf str;
    buf

# 11 "common/shell_lexer.ml"
let __ocaml_lex_tables = {
  Lexing.lex_base = 
   "\000\000\245\255\247\255\248\255\001\000\004\000\005\000\249\255\
    \250\255\251\255\252\255\253\255\010\000\013\000\248\255\249\255\
    \014\000\255\255\009\000\250\255\251\255\252\255\253\255\254\255\
    \016\000\017\000\020\000\046\000\253\255\254\255\255\255\047\000\
    \249\255\250\255\251\255\018\000\019\000\050\000\253\255\254\255\
    \255\255\051\000";
  Lexing.lex_backtrk = 
   "\255\255\255\255\255\255\255\255\009\000\001\000\000\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\008\000\255\255\255\255\
    \009\000\255\255\000\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\007\000\008\000\003\000\255\255\255\255\255\255\000\000\
    \255\255\255\255\255\255\255\255\004\000\003\000\255\255\255\255\
    \255\255\000\000";
  Lexing.lex_default = 
   "\005\000\000\000\000\000\000\000\007\000\005\000\255\255\000\000\
    \000\000\000\000\000\000\000\000\013\000\013\000\000\000\000\000\
    \019\000\000\000\255\255\000\000\000\000\000\000\000\000\000\000\
    \025\000\025\000\032\000\255\255\000\000\000\000\000\000\255\255\
    \000\000\000\000\000\000\036\000\036\000\255\255\000\000\000\000\
    \000\000\255\255";
  Lexing.lex_trans = 
   "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\006\000\000\000\000\000\000\000\255\255\006\000\000\000\
    \000\000\000\000\018\000\018\000\000\000\000\000\255\255\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \006\000\008\000\003\000\011\000\255\255\006\000\255\255\002\000\
    \010\000\018\000\018\000\255\255\015\000\255\255\020\000\255\255\
    \023\000\014\000\027\000\255\255\255\255\022\000\034\000\031\000\
    \031\000\037\000\255\255\041\000\041\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\031\000\031\000\
    \029\000\000\000\041\000\041\000\038\000\028\000\000\000\000\000\
    \000\000\039\000\000\000\000\000\004\000\009\000\000\000\000\000\
    \255\255\000\000\000\000\000\000\000\000\000\000\016\000\000\000\
    \000\000\255\255\021\000\000\000\026\000\255\255\000\000\000\000\
    \033\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \001\000\255\255\000\000\000\000\255\255\000\000\000\000\000\000\
    \000\000\000\000\017\000\000\000\000\000\255\255\255\255\000\000\
    \255\255\255\255\255\255\255\255\255\255\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\030\000\000\000\
    \000\000\000\000\040\000\000\000";
  Lexing.lex_check = 
   "\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\000\000\255\255\255\255\255\255\005\000\006\000\255\255\
    \255\255\255\255\018\000\012\000\255\255\255\255\013\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \000\000\004\000\000\000\004\000\005\000\006\000\005\000\000\000\
    \004\000\018\000\012\000\005\000\012\000\013\000\016\000\013\000\
    \016\000\012\000\024\000\025\000\013\000\016\000\026\000\027\000\
    \031\000\035\000\036\000\037\000\041\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\027\000\031\000\
    \027\000\255\255\037\000\041\000\037\000\027\000\255\255\255\255\
    \255\255\037\000\255\255\255\255\000\000\004\000\255\255\255\255\
    \005\000\255\255\255\255\255\255\255\255\255\255\012\000\255\255\
    \255\255\013\000\016\000\255\255\024\000\025\000\255\255\255\255\
    \026\000\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \000\000\004\000\255\255\255\255\005\000\255\255\255\255\255\255\
    \255\255\255\255\012\000\255\255\255\255\013\000\016\000\255\255\
    \024\000\025\000\035\000\036\000\026\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\027\000\255\255\
    \255\255\255\255\037\000\255\255";
  Lexing.lex_base_code = 
   "";
  Lexing.lex_backtrk_code = 
   "";
  Lexing.lex_default_code = 
   "";
  Lexing.lex_trans_code = 
   "";
  Lexing.lex_check_code = 
   "";
  Lexing.lex_code = 
   "";
}

let rec shell_command argv lexbuf =
    __ocaml_lex_shell_command_rec argv lexbuf 0
and __ocaml_lex_shell_command_rec argv lexbuf __ocaml_lex_state =
  match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf with
      | 0 ->
# 26 "common/shell_lexer.mll"
                 ( shell_command argv lexbuf )
# 135 "common/shell_lexer.ml"

  | 1 ->
# 27 "common/shell_lexer.mll"
                 ( uquote argv (buf_from_str (Lexing.lexeme lexbuf)) lexbuf )
# 140 "common/shell_lexer.ml"

  | 2 ->
# 28 "common/shell_lexer.mll"
                 ( uquote argv (buf_from_str "\"") lexbuf )
# 145 "common/shell_lexer.ml"

  | 3 ->
# 29 "common/shell_lexer.mll"
                 ( uquote argv (buf_from_str "'") lexbuf )
# 150 "common/shell_lexer.ml"

  | 4 ->
# 30 "common/shell_lexer.mll"
                 ( uquote argv (buf_from_str "\\") lexbuf )
# 155 "common/shell_lexer.ml"

  | 5 ->
# 31 "common/shell_lexer.mll"
                 ( uquote argv (buf_from_str " ") lexbuf )
# 160 "common/shell_lexer.ml"

  | 6 ->
let
# 32 "common/shell_lexer.mll"
             c
# 166 "common/shell_lexer.ml"
= Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos (lexbuf.Lexing.lex_start_pos + 2) in
# 32 "common/shell_lexer.mll"
                 ( raise (UnknownShellEscape c) )
# 170 "common/shell_lexer.ml"

  | 7 ->
# 33 "common/shell_lexer.mll"
                 ( dquote argv (Buffer.create 16) lexbuf )
# 175 "common/shell_lexer.ml"

  | 8 ->
# 34 "common/shell_lexer.mll"
                 ( squote argv (Buffer.create 16) lexbuf )
# 180 "common/shell_lexer.ml"

  | 9 ->
let
# 35 "common/shell_lexer.mll"
        c
# 186 "common/shell_lexer.ml"
= Lexing.sub_lexeme_char lexbuf lexbuf.Lexing.lex_start_pos in
# 35 "common/shell_lexer.mll"
                 ( raise (UnmatchedChar c) )
# 190 "common/shell_lexer.ml"

  | 10 ->
# 36 "common/shell_lexer.mll"
       ( List.rev argv )
# 195 "common/shell_lexer.ml"

  | __ocaml_lex_state -> lexbuf.Lexing.refill_buff lexbuf; 
      __ocaml_lex_shell_command_rec argv lexbuf __ocaml_lex_state

and uquote argv buf lexbuf =
    __ocaml_lex_uquote_rec argv buf lexbuf 12
and __ocaml_lex_uquote_rec argv buf lexbuf __ocaml_lex_state =
  match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf with
      | 0 ->
# 38 "common/shell_lexer.mll"
               ( shell_command ((Buffer.contents buf)::argv) lexbuf )
# 207 "common/shell_lexer.ml"

  | 1 ->
# 39 "common/shell_lexer.mll"
               ( Buffer.add_string buf "\""; uquote argv buf lexbuf )
# 212 "common/shell_lexer.ml"

  | 2 ->
# 40 "common/shell_lexer.mll"
               ( Buffer.add_string buf "'"; uquote argv buf lexbuf )
# 217 "common/shell_lexer.ml"

  | 3 ->
# 41 "common/shell_lexer.mll"
               ( Buffer.add_string buf "\\"; uquote argv buf lexbuf )
# 222 "common/shell_lexer.ml"

  | 4 ->
# 42 "common/shell_lexer.mll"
               ( Buffer.add_string buf " "; uquote argv buf lexbuf )
# 227 "common/shell_lexer.ml"

  | 5 ->
let
# 43 "common/shell_lexer.mll"
             c
# 233 "common/shell_lexer.ml"
= Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos (lexbuf.Lexing.lex_start_pos + 2) in
# 43 "common/shell_lexer.mll"
               ( raise (UnknownShellEscape c) )
# 237 "common/shell_lexer.ml"

  | 6 ->
# 44 "common/shell_lexer.mll"
               ( dquote argv buf lexbuf )
# 242 "common/shell_lexer.ml"

  | 7 ->
# 45 "common/shell_lexer.mll"
               ( squote argv buf lexbuf )
# 247 "common/shell_lexer.ml"

  | 8 ->
# 46 "common/shell_lexer.mll"
               ( Buffer.add_string buf (Lexing.lexeme lexbuf); uquote argv buf lexbuf )
# 252 "common/shell_lexer.ml"

  | 9 ->
let
# 47 "common/shell_lexer.mll"
        c
# 258 "common/shell_lexer.ml"
= Lexing.sub_lexeme_char lexbuf lexbuf.Lexing.lex_start_pos in
# 47 "common/shell_lexer.mll"
               ( raise (UnmatchedChar c) )
# 262 "common/shell_lexer.ml"

  | __ocaml_lex_state -> lexbuf.Lexing.refill_buff lexbuf; 
      __ocaml_lex_uquote_rec argv buf lexbuf __ocaml_lex_state

and dquote argv buf lexbuf =
    __ocaml_lex_dquote_rec argv buf lexbuf 24
and __ocaml_lex_dquote_rec argv buf lexbuf __ocaml_lex_state =
  match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf with
      | 0 ->
# 49 "common/shell_lexer.mll"
                   ( shell_command ((Buffer.contents buf)::argv) lexbuf )
# 274 "common/shell_lexer.ml"

  | 1 ->
# 50 "common/shell_lexer.mll"
                   ( dquote argv buf lexbuf )
# 279 "common/shell_lexer.ml"

  | 2 ->
# 51 "common/shell_lexer.mll"
                   ( squote argv buf lexbuf )
# 284 "common/shell_lexer.ml"

  | 3 ->
# 52 "common/shell_lexer.mll"
                   ( uquote argv buf lexbuf )
# 289 "common/shell_lexer.ml"

  | 4 ->
# 53 "common/shell_lexer.mll"
                   ( Buffer.add_string buf "\""; dquote argv buf lexbuf )
# 294 "common/shell_lexer.ml"

  | 5 ->
# 54 "common/shell_lexer.mll"
                   ( Buffer.add_string buf "\\"; dquote argv buf lexbuf )
# 299 "common/shell_lexer.ml"

  | 6 ->
let
# 55 "common/shell_lexer.mll"
             c
# 305 "common/shell_lexer.ml"
= Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos (lexbuf.Lexing.lex_start_pos + 2) in
# 55 "common/shell_lexer.mll"
                   ( raise (UnknownShellEscape c) )
# 309 "common/shell_lexer.ml"

  | 7 ->
# 56 "common/shell_lexer.mll"
                   ( Buffer.add_string buf (Lexing.lexeme lexbuf); dquote argv buf lexbuf )
# 314 "common/shell_lexer.ml"

  | 8 ->
let
# 57 "common/shell_lexer.mll"
        c
# 320 "common/shell_lexer.ml"
= Lexing.sub_lexeme_char lexbuf lexbuf.Lexing.lex_start_pos in
# 57 "common/shell_lexer.mll"
                   ( raise (UnmatchedChar c) )
# 324 "common/shell_lexer.ml"

  | __ocaml_lex_state -> lexbuf.Lexing.refill_buff lexbuf; 
      __ocaml_lex_dquote_rec argv buf lexbuf __ocaml_lex_state

and squote argv buf lexbuf =
    __ocaml_lex_squote_rec argv buf lexbuf 35
and __ocaml_lex_squote_rec argv buf lexbuf __ocaml_lex_state =
  match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf with
      | 0 ->
# 59 "common/shell_lexer.mll"
                   ( shell_command ((Buffer.contents buf)::argv) lexbuf )
# 336 "common/shell_lexer.ml"

  | 1 ->
# 60 "common/shell_lexer.mll"
                   ( squote argv buf lexbuf )
# 341 "common/shell_lexer.ml"

  | 2 ->
# 61 "common/shell_lexer.mll"
                   ( dquote argv buf lexbuf )
# 346 "common/shell_lexer.ml"

  | 3 ->
# 62 "common/shell_lexer.mll"
                   ( uquote argv buf lexbuf )
# 351 "common/shell_lexer.ml"

  | 4 ->
# 63 "common/shell_lexer.mll"
                   ( Buffer.add_string buf (Lexing.lexeme lexbuf); squote argv buf lexbuf )
# 356 "common/shell_lexer.ml"

  | 5 ->
let
# 64 "common/shell_lexer.mll"
        c
# 362 "common/shell_lexer.ml"
= Lexing.sub_lexeme_char lexbuf lexbuf.Lexing.lex_start_pos in
# 64 "common/shell_lexer.mll"
                   ( raise (UnmatchedChar c) )
# 366 "common/shell_lexer.ml"

  | __ocaml_lex_state -> lexbuf.Lexing.refill_buff lexbuf; 
      __ocaml_lex_squote_rec argv buf lexbuf __ocaml_lex_state

;;

# 66 "common/shell_lexer.mll"
 
  (** given a (possibly quoted) command string, parse it into an argument vector *)
  let parse_string str =
    let lexbuf = Lexing.from_string str in
    shell_command [] lexbuf

# 380 "common/shell_lexer.ml"

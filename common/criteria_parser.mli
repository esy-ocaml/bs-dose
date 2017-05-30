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

val criteria_top :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Criteria_types.criteria

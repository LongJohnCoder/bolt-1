(** This is the entry point for execution of Bolt programs. *)

val run_program :
     ?should_pprint_past:bool
  -> ?should_pprint_tast:bool
  -> ?print_execution:bool
  -> Lexing.lexbuf
  -> unit

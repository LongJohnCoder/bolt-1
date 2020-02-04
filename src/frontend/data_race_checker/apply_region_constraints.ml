open Core
open Data_race_checker_ast
open Ast.Ast_types

let apply_regions_cap_constraints regions
    { linear= linear_allowed
    ; read= read_allowed
    ; thread= thread_allowed
    ; subordinate= subord_allowed
    ; locked= locked_allowed } =
  let maybe_remove_regions_with_cap cap_allowed cap regions =
    if cap_allowed then regions
    else List.filter ~f:(fun (TRegion (reg_cap, _)) -> not (reg_cap = cap)) regions in
  maybe_remove_regions_with_cap linear_allowed Linear regions
  |> maybe_remove_regions_with_cap read_allowed Read
  |> maybe_remove_regions_with_cap thread_allowed Thread
  |> maybe_remove_regions_with_cap subord_allowed Subordinate
  |> maybe_remove_regions_with_cap locked_allowed Locked

let apply_regions_cap_constraints_identifier = function
  | Variable (var_type, name, regions, caps) ->
      Variable (var_type, name, apply_regions_cap_constraints regions caps, caps)
  | ObjField (obj_class, obj_name, field_type, field_name, regions, caps) ->
      ObjField (obj_class, obj_name, field_type, field_name, regions, caps)

let rec apply_regions_cap_constraints_expr expr =
  match expr with
  | Integer _ | Boolean _ -> expr
  | Identifier (loc, id) -> Identifier (loc, apply_regions_cap_constraints_identifier id)
  | BlockExpr (loc, block_expr) ->
      BlockExpr (loc, apply_regions_cap_constraints_block_expr block_expr)
  | Constructor (loc, type_expr, class_name, constructor_args) ->
      let updated_args =
        List.map
          ~f:(fun (ConstructorArg (type_expr, field_name, expr)) ->
            ConstructorArg (type_expr, field_name, apply_regions_cap_constraints_expr expr))
          constructor_args in
      Constructor (loc, type_expr, class_name, updated_args)
  | Let (loc, type_expr, var_name, bound_expr) ->
      Let (loc, type_expr, var_name, apply_regions_cap_constraints_expr bound_expr)
  | Assign (loc, type_expr, id, assigned_expr) ->
      Assign
        ( loc
        , type_expr
        , apply_regions_cap_constraints_identifier id
        , apply_regions_cap_constraints_expr assigned_expr )
  | Consume (loc, id) -> Consume (loc, apply_regions_cap_constraints_identifier id)
  | MethodApp (loc, type_expr, obj_name, obj_type, method_name, args) ->
      MethodApp
        ( loc
        , type_expr
        , obj_name
        , obj_type
        , method_name
        , List.map ~f:apply_regions_cap_constraints_expr args )
  | FunctionApp (loc, return_type, func_name, args) ->
      FunctionApp
        (loc, return_type, func_name, List.map ~f:apply_regions_cap_constraints_expr args)
  | Printf (loc, format_str, args) ->
      Printf (loc, format_str, List.map ~f:apply_regions_cap_constraints_expr args)
  | FinishAsync (loc, type_expr, async_exprs, curr_thread_free_vars, curr_thread_expr) ->
      FinishAsync
        ( loc
        , type_expr
        , List.map
            ~f:(fun (AsyncExpr (free_vars, expr)) ->
              AsyncExpr (free_vars, apply_regions_cap_constraints_block_expr expr))
            async_exprs
        , curr_thread_free_vars
        , apply_regions_cap_constraints_block_expr curr_thread_expr )
  | If (loc, type_expr, cond_expr, then_expr, else_expr) ->
      If
        ( loc
        , type_expr
        , apply_regions_cap_constraints_expr cond_expr
        , apply_regions_cap_constraints_block_expr then_expr
        , apply_regions_cap_constraints_block_expr else_expr )
  | While (loc, cond_expr, loop_expr) ->
      While
        ( loc
        , apply_regions_cap_constraints_expr cond_expr
        , apply_regions_cap_constraints_block_expr loop_expr )
  | BinOp (loc, type_expr, binop, expr1, expr2) ->
      BinOp
        ( loc
        , type_expr
        , binop
        , apply_regions_cap_constraints_expr expr1
        , apply_regions_cap_constraints_expr expr2 )
  | UnOp (loc, type_expr, unop, expr) ->
      UnOp (loc, type_expr, unop, apply_regions_cap_constraints_expr expr)

and apply_regions_cap_constraints_block_expr (Block (loc, type_block_expr, exprs)) =
  let updated_exprs = List.map ~f:apply_regions_cap_constraints_expr exprs in
  Block (loc, type_block_expr, updated_exprs)

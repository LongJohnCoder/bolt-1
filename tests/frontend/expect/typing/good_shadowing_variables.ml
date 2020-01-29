open Core
open Print_typed_ast

let%expect_test "Variable shadowing in different blocks" =
  print_typed_ast
    "
    class Foo {
      region read Bar;
      const int f : Bar;
    }
    void main(){
    let x = 6; 
      if true {
        let x = new Foo(f:5); (* shadowing in an inner block is okay *)
        let y = -5; 
        finish{
          async {
            x;
            y
          };
          async{
            x;
            y
          }
          x
        };
        x.f
      }
      else {
         5
      }
    }
  " ;
  [%expect
    {|
    Program
    └──Class: Foo
       └──Regions:
          └──Region: Read Bar
       └──Field Defn: f
          └──Mode: Const
          └──Type expr: Int
          └──Regions: Bar
    └──Expr: Block
       └──Type expr: Int
       └──Expr: Let var: _var_x0
          └──Type expr: Int
          └──Expr: Int:6
       └──Expr: If
          └──Type expr: Int
          └──Expr: Bool:true
          └──Expr: Block
             └──Type expr: Int
             └──Expr: Let var: _var_x1
                └──Type expr: Class: Foo
                └──Expr: Constructor for: Foo
                   └──Type expr: Class: Foo
                   └── Field: f
                      └──Type expr: Int
                      └──Expr: Int:5
             └──Expr: Let var: _var_y0
                └──Type expr: Int
                └──Expr: Int:-5
             └──Expr: Finish_async
                └──Type expr: Class: Foo
                └── Async Expr:
                   └──Expr: Block
                      └──Type expr: Int
                      └──Expr: Variable: _var_x1
                         └──Type expr: Class: Foo
                      └──Expr: Variable: _var_y0
                         └──Type expr: Int
                └── Async Expr:
                   └──Expr: Block
                      └──Type expr: Int
                      └──Expr: Variable: _var_x1
                         └──Type expr: Class: Foo
                      └──Expr: Variable: _var_y0
                         └──Type expr: Int
                └──Expr: Block
                   └──Type expr: Class: Foo
                   └──Expr: Variable: _var_x1
                      └──Type expr: Class: Foo
             └──Expr: Objfield: (Class: Foo) _var_x1.f
                └──Type expr: Int
          └──Expr: Block
             └──Type expr: Int
             └──Expr: Int:5 |}]
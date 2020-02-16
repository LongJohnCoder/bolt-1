open Core
open Print_data_race_checker_ast

let%expect_test "Consume this" =
  print_data_race_checker_ast
    " 
    class Foo {
      region linear Bar;
      const int f : Bar;
      Foo test() : Bar {
         consume this
      }

    }
    void main(){
    }
  " ;
  [%expect {|
    Line:6 Position:10 Type error - Trying to consume 'this'. |}]

let%expect_test "Consume variable twice" =
  print_data_race_checker_ast
    " 
    class Foo {
      region linear Bar;
      const int f : Bar;

    }
    void main(){
      let x = new Foo();
      consume x;
      consume x
    }
  " ;
  [%expect
    {|
    Type error: Variable Variable: _var_x0 accessed after being consumed. |}]

let%expect_test "Access variable after consumption" =
  print_data_race_checker_ast
    " 
    class Foo {
      region linear Bar;
      const int f : Bar;

    }
    void main(){
      let x = new Foo();
      consume x;
      x
    }
  " ;
  [%expect
    {|
    Type error: Variable Variable: _var_x0 accessed after being consumed. |}]

let%expect_test "Access field after consumption of object" =
  print_data_race_checker_ast
    " 
    class Foo {
      region linear Bar;
      const int f : Bar;

    }
    void main(){
      let x = new Foo();
      consume x;
      x.f
    }
  " ;
  [%expect
    {|
    Type error: Variable Objfield: (Class: Foo) _var_x0.f accessed after being consumed. |}]

let%expect_test "Access field after consumption of field" =
  print_data_race_checker_ast
    " 
    class Foo {
      region linear Bar;
      const int f : Bar;

    }
    void main(){
      let x = new Foo();
      consume x.f;
      x.f
    }
  " ;
  [%expect {|
    Line:9 Position:7 Type error - Trying to consume a const field. |}]

let%expect_test "Access field after consumption of field even though restored in function body"
    =
  print_data_race_checker_ast
    " 
    class Foo {
      region linear Bar;
      var int f : Bar;
    }
    function void f(Foo x){
        x.f := 5
    }
    void main(){
      let x = new Foo();
      consume x.f;
      f(x); // Note local analysis means we don't look at body of function call *)
      x.f
    }
  " ;
  [%expect
    {|
    Type error: Trying to consume Objfield: (Class: Foo) _var_x0.f but it is not linear |}]

let%expect_test "Consume in a loop" =
  print_data_race_checker_ast
    " 
    class Foo {
      region linear Bar;
      var int f : Bar;
      var int g : Bar;
    }
    function void f(Foo x){
        x.f := 5
    }
    void main(){
      let x = new Foo(g:1);
      while(x.g < 10){
        consume x.f;
        x.g := x.g + 1
      }
    }
  " ;
  [%expect
    {|
    Type error: Trying to consume Objfield: (Class: Foo) _var_x0.f but it is not linear |}]

let%expect_test "Consume in a condition of a loop" =
  print_data_race_checker_ast
    " 
    class Foo {
      region linear Bar;
      var int f : Bar;
      var int g : Bar;
    }
    function void f(Foo x){
        x.f := 5
    }
    void main(){
      let x = new Foo(g:1);
      while((consume x.f) < 10){
          x.g := x.g + 1
      }
    }
  " ;
  [%expect
    {|
    Type error: Trying to consume Objfield: (Class: Foo) _var_x0.f but it is not linear |}]

let%expect_test "Consume shared variable if accessed by another thread" =
  print_data_race_checker_ast
    " 
    class Foo {
      region linear Bar;
      var int f : Bar;
      int test() : Bar { this.f } 
    }
    void main(){
      let x = new Foo();
      let y = new Foo(f:10);
      finish{
        async{
          consume y // accessed by other thread *) 
        }
        for( x.f := y.f ; x.f > 0 ; x.f := x.f + -1) {
          let w = if ((!(x.f > 5)) || false){ 100} else {50 }
        }
       }
    }
  " ;
  [%expect {|
      Type error: shared variable _var_y0 was consumed.
|}]

let%expect_test "Consume nonlinear object" =
  print_data_race_checker_ast
    " 
    class Choco {
       region thread Late;
      const int f : Late;
    }
    void main(){
        let x = new Choco(f:4);
        let y = consume x // Can't consume nonlinear variable 
      }  " ;
  [%expect {|
    Type error: Trying to consume Variable: _var_x0 but it is not linear |}]

let%expect_test "Consume int" =
  print_data_race_checker_ast
    " 
    void main(){
        let z = 5;
        let w = consume z // Can't consume an int 
      }  " ;
  [%expect {|
    Type error: Trying to consume Variable: _var_z0 but it is not linear |}]

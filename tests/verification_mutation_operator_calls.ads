--  The calls of verification_operator_calls with what makes them wrong:
--  each precondition of an operator here may fail, and none is proved.
--  None is a definite error either: which function an instance calls is
--  GNAT's to say.
package Verification_Mutation_Operator_Calls
  with SPARK_Mode
is
   generic
      type Custom_Index is range <>;
      type Custom_Length is range <>;
   package Types is
      subtype Index is Custom_Index;
      subtype Length is Custom_Length;

      function "+" (Left : Index; Right : Index) return Index is abstract;
      function "-" (Left : Index; Right : Index) return Index is abstract;

      generic
      package Operators is
         --  The names of the formals are crossed: Right is the left
         --  operand, and only it counts.
         function "+" (Right : Index; Left : Length) return Index is
           (Index (Length (Right) + Left))
         with Pre => Length (Right) <= 3 and then Left <= 9;

         function "-" (Left : Index; Right : Index) return Length is
           (Length (Left) - Length (Right))
         with Pre => Length (Left) >= Length'First + Length (Right);

         function "-" (Left : Index; Right : Length) return Index is
           (Index (Length (Left) - Right))
         with Pre => Right < Length'Last
           and then Length (Left) >= Length (Index'First) + Right;
      end Operators;

      generic
         with package Ops is new Operators (<>);
      package User is
         use Ops;

         --  The left operand is the formal named Right: by name, the call
         --  would give it 1 and prove it.
         function Crossed (I : Index) return Index
           with Pre => Length (I) in 5 .. 9;

         function Unchecked (I : Index) return Index;

         --  R may be Index'First, and R - 1 below it.
         function Bound (L, R : Index) return Natural;

         --  Nothing says R is not below L.
         function Reversed (L, R : Index) return Length;
      end User;
   end Types;

   type Idx is range 1 .. 1000;
   type Len is range 0 .. 1000;
end Verification_Mutation_Operator_Calls;

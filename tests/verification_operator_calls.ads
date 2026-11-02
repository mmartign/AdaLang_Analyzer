--  An operator a generic unit hides behind an abstract function, as the
--  RecordFlux runtime does for Index, calls the function of its symbol that
--  takes the operands, and the precondition of that function is checked at
--  the operator. The function's formals take the operands by position: their
--  names mean nothing. As the operand of a type conversion, an operation
--  whose operands are both of the formal type calls the predefined operator
--  of the actual in each instance GNAT makes, and has its checks.
--  Every claim here holds. verification_mutation_operator_calls has those
--  that do not.
package Verification_Operator_Calls
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

         function Next (I : Index) return Index
           with Pre => Length (I) <= 2;

         --  R - 1 bounds a range: the function of "-" that returns an
         --  Index, as the other bound is one.
         function Count (L, R : Index) return Natural
           with Pre => R > Index'First;

         function Span (L, R : Index) return Length
           with Pre => L <= R;

         function Converted (L, R : Index) return Natural
           with Pre => L <= R;
      end User;
   end Types;

   type Idx is range 1 .. 1000;
   type Len is range 0 .. 1000;
end Verification_Operator_Calls;

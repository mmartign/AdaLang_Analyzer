--  FP-116: an operator symbol does not say what the operation is. Where a
--  declaration defines a function for it, the operation is a call of that
--  function, whatever the symbol reads as. None of the functions here
--  computes what its symbol stands for.
package Verification_FP116_Declared_Operator with SPARK_Mode is

   type Level is range 0 .. 1000;

   --  The distance between the two, not their sum.
   function "+" (Left, Right : Level) return Level
   is (Level (abs (Integer (Left) - Integer (Right))));

   --  The smaller of the two.
   function "*" (Left, Right : Level) return Level
   is (Level (Integer'Min (Integer (Left), Integer (Right))));

   --  The left operand: a right operand of zero is no error, one of one is
   --  not allowed.
   function "/" (Left, Right : Level) return Level
   is (Left)
   with Pre => Integer (Right) /= 1;

   function "mod" (Left, Right : Level) return Level is (Right);

   function "**" (Left : Level; Right : Natural) return Level is (Left);

   function "-" (Right : Level) return Level is (Right);

   function "abs" (Right : Level) return Level is (0);

   --  The order reversed.
   function "<" (Left, Right : Level) return Boolean
   is (Integer (Left) > Integer (Right));

   --  Never equal, and so always different: "/=" is the complement of this
   --  function.
   function "=" (Left, Right : Level) return Boolean is (False);

   --  Another function under the name of an operator.
   function Keep (Left : Level; Right : Integer) return Level is (Left);

   function "+" (Left : Level; Right : Integer) return Level renames Keep;

   --  A derived type has them all.
   type Grade is new Level;

   type Table is array (Level range <>) of Natural;

   procedure Sum;
   procedure Distance;
   procedure Product;
   procedure Remainder;
   procedure Power;
   procedure Negation;
   procedure Magnitude;
   procedure Order;
   procedure Order_Reversed;
   procedure Order_Branch (Left, Right : Level);
   procedure Same;
   procedure Different;
   procedure Not_Different;
   procedure Different_Branch (Left, Right : Level);
   procedure Operand;
   procedure Member;
   procedure Bound;
   procedure Element;
   procedure Narrowed;
   procedure Inherited;
   procedure Renamed;
   procedure Whole_Numbers;
   procedure Both;
   procedure Either;
   procedure Opposite;
   procedure Exclusive;
   procedure Quotient;

end Verification_FP116_Declared_Operator;

--  A quantified expression in a Loop_Invariant or in an Assert_And_Cut is
--  decided as one in an Assert is. It does not put the subprogram outside
--  the verification subset.
package Verification_Quantified_Invariant with SPARK_Mode is

   type Table is array (1 .. 10) of Integer;

   --  Holds when the loop is entered and after each iteration.
   procedure Kept (Data : in out Table);

   --  Holds when the loop is entered; the body breaks it.
   procedure Broken (Data : in out Table);

   --  The range of the quantifier grows in the body.
   procedure Widened (Data : in out Table);

   --  Does not hold when the loop is entered.
   procedure Never_True (Data : in out Table; Result : out Integer);

   --  A division inside the predicate, by zero for one of the values.
   procedure Inside (Data : in out Table);

   --  An Assert_And_Cut that does not hold.
   procedure Cut (Result : out Integer);

end Verification_Quantified_Invariant;

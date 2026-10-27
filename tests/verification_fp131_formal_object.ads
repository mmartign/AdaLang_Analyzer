--  FP-131: a formal object of mode in is a constant (RM 12.4(9)), though
--  its declaration has no reserved word "constant", so X'Constrained is
--  True of it and of each of its components. It was taken for a variable,
--  and "not X'Constrained" was proved of an X of a type with defaulted
--  discriminants: GNAT warns that the assertion will fail at run time, and
--  it does.
package Verification_FP131_Formal_Object with SPARK_Mode is

   type Ctx (Size : Natural := 0) is record
      Value : Integer := 0;
   end record;

   type Holder is record
      Part : Ctx;
   end record;

   generic
      Whole : Ctx;
      Outer : Holder;
   package Formal is
      procedure Check_Whole;
      procedure Check_Part;
   end Formal;

end Verification_FP131_Formal_Object;

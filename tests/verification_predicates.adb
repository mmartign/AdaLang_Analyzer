package body Verification_Predicates with SPARK_Mode => On is

   function Get_A (Ctx : Context) return Natural is (Ctx.Cur (F_A).First);

   procedure Set_C (Ctx : in out Context) is
   begin
      Ctx.Cur := (others => (St => S_Valid, First => 0, Last => 0));
   end Set_C;

   --  The third field is valid, so the second is, so the first is.
   procedure At_Entry (Entered : Context; N : out Natural) is
   begin
      N := Get_A (Entered);
   end At_Entry;

   --  The quantified part of the predicate holds of the second field.
   procedure Bounded (Sized : Context) is
   begin
      pragma Assert (Sized.Cur (F_B).First <= Sized.Cur (F_B).Last);
      pragma Assert (Sized.Cur (F_B).Last <= 1000);
   end Bounded;

   --  Which keeps an addition within its type.
   procedure No_Overflow (Wide : Context; N : out Natural) is
   begin
      N := Wide.Cur (F_B).Last + 1;
   end No_Overflow;

   --  The callee returns the third field valid, and the object satisfying
   --  its predicate.
   procedure After_Call (Called : in out Context; N : out Natural) is
   begin
      Set_C (Called);
      N := Get_A (Called);
   end After_Call;

   --  So does a part of an object that is given to it.
   procedure Part_Given (Box : in out Holder; N : out Natural) is
   begin
      Set_C (Box.Inner);
      N := Get_A (Box.Inner);
   end Part_Given;

   --  A subtype has the predicate of what it is a subtype of, and its own.
   procedure Both_Predicates (Brief : Short_Context) is
   begin
      pragma Assert (Brief.Limit <= 10);
      pragma Assert (Brief.Limit <= 1000);
   end Both_Predicates;

   --  The call in the postcondition is made where the subprogram returns.
   procedure In_Postcondition (Posted : in out Context) is
   begin
      Set_C (Posted);
   end In_Postcondition;

end Verification_Predicates;

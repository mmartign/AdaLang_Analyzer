package body Verification_Condition_Parts with SPARK_Mode => On is

   --  One part of what the conditional expression selects reads an element
   --  at an index that is not known; the other part is taken all the same.
   procedure Selected (On : Boolean; Chosen : Integer; T : Table; I : Place)
   is
   begin
      if On then
         pragma Assert (Chosen > 0);
      end if;
   end Selected;

   --  What the else part selects holds where the condition does not.
   procedure Otherwise (On : Boolean; Left, Right : Integer) is
   begin
      if not On then
         pragma Assert (Right > 0);
      end if;
   end Otherwise;

   --  The quantified expression holds of each value of the type.
   procedure Each_Value (Graded : Marks) is
   begin
      pragma Assert (Graded (Second) > 0);
   end Each_Value;

   --  And of each value of a subtype of it.
   procedure Each_In_Subtype (Scored : Marks) is
   begin
      pragma Assert (Scored (Third) > 0);
   end Each_In_Subtype;

   --  And of each value of a range of integers.
   procedure Each_In_Range (Filled : Table) is
   begin
      pragma Assert (Filled (3) >= 0);
   end Each_In_Range;

   --  The first actual has no term: the part of the body that reads the
   --  second formal alone is taken.
   procedure Body_Read (T : Table; I : Place; Kept : Integer) is
   begin
      pragma Assert (Kept > 0);
   end Body_Read;

   --  The body is a quantified expression.
   procedure Body_Quantified (Ranked : Marks) is
   begin
      pragma Assert (Ranked (Third) > 0);
   end Body_Quantified;

   --  The body is a conditional expression that calls another function.
   procedure Body_Guarded (On : Boolean; Sorted : Marks) is
   begin
      if On then
         pragma Assert (Sorted (Second) > 0);
      end if;
   end Body_Guarded;

end Verification_Condition_Parts;

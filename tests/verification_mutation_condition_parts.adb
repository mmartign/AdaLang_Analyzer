package body Verification_Mutation_Condition_Parts with SPARK_Mode => On is

   --  The condition that selects the part is not known to hold.
   procedure Not_Selected (On : Boolean; Loose : Integer) is
   begin
      pragma Assert (Loose > 0);
   end Not_Selected;

   --  The part belongs to the branch that was not taken.
   procedure Other_Branch (On : Boolean; Left, Stray : Integer) is
   begin
      if On then
         pragma Assert (Stray > 0);
      end if;
   end Other_Branch;

   --  The value is not one of the subtype the expression ranges over.
   procedure Outside_Subtype (Scored : Marks) is
   begin
      pragma Assert (Scored (First) > 0);
   end Outside_Subtype;

   --  Nor one that satisfies the predicate of the subtype, which the
   --  expression does not range over either.
   procedure Outside_Predicate (Sparse : Marks) is
   begin
      pragma Assert (Sparse (Second) > 0);
   end Outside_Predicate;

   --  Nor is the index in the range.
   procedure Outside_Range (Filled : Table) is
   begin
      pragma Assert (Filled (5) >= 0);
   end Outside_Range;

   --  More is claimed than the predicate says of the value.
   procedure Stronger (Graded : Marks) is
   begin
      pragma Assert (Graded (Second) > 1);
   end Stronger;

   --  A quantified expression that does not hold says nothing of any one
   --  value.
   procedure Not_All (Mixed : Marks) is
   begin
      pragma Assert (Mixed (First) <= 0);
   end Not_All;

   --  What the body says of its first formal is said of the element at I,
   --  not of another.
   procedure Other_Actual (T : Table; I, J : Place; Kept : Integer) is
   begin
      pragma Assert (T (J) > 0);
   end Other_Actual;

   --  A formal whose actual has no term stands for nothing: what the body
   --  says of it is known of no element.
   procedure Formal_Is_No_Object (T : Table; I, J : Place) is
   begin
      pragma Assert (Low (T (J)));
   end Formal_Is_No_Object;

   --  A call that returned False is not its body failing part by part.
   procedure Not_Returned_True (Ranked : Marks) is
   begin
      pragma Assert (Ranked (First) <= 0);
   end Not_Returned_True;

end Verification_Mutation_Condition_Parts;

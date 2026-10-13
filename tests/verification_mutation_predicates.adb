package body Verification_Mutation_Predicates with SPARK_Mode => On is

   procedure Scramble (Ctx : in out Context) with SPARK_Mode => Off is
   begin
      Ctx.Limit := 2000;
   end Scramble;

   procedure Renew (Ctx : in out Context) is
   begin
      Ctx.Cur := (others => <>);
   end Renew;

   --  The predicate leads from a field to the ones before it, not on.
   procedure Wrong_Way (Lower : Context) is
   begin
      pragma Assert (Valid (Lower, F_C));
   end Wrong_Way;

   --  More is claimed than the predicate says.
   procedure Stronger (Strict : Context) is
   begin
      pragma Assert (Strict.Limit <= 999);
   end Stronger;

   --  And more than the predicate of the subtype says.
   procedure Stronger_Subtype (Brief : Short_Context) is
   begin
      pragma Assert (Brief.Limit <= 9);
   end Stronger_Subtype;

   --  What is known of one object is not known of another.
   procedure Other_Object (Known, Other : Context) is
   begin
      pragma Assert (Valid (Other, F_A));
   end Other_Object;

   --  A parameter that is not given a value has none to satisfy the
   --  predicate, and the value assigned to it is not taken to.
   procedure Out_Parameter (Made : out Context) is
   begin
      Made := (Limit => 2000, Cur => (others => <>));
      pragma Assert (Made.Limit <= 1000);
   end Out_Parameter;

   --  The component has been assigned since the subprogram was entered.
   procedure Component_Written (Edited : in out Context; Step : Natural) is
   begin
      Edited.Limit := Edited.Limit + Step;
      pragma Assert (Edited.Limit <= 1000);
   end Component_Written;

   --  What the predicate said of two components it said of the values
   --  they had: one has another value now.
   procedure Other_Component_Written (Tied : in out Context) is
   begin
      Tied.Limit := 5;
      pragma Assert (Tied.Cur (F_A).Last <= 5);
   end Other_Component_Written;

   --  An element at an index that is not known has been assigned.
   procedure Element_Written (Moved : in out Context; Where : Field) is
   begin
      Moved.Cur (Where).St := S_Invalid;
      pragma Assert (Valid (Moved, F_A));
   end Element_Written;

   --  The whole object has been assigned.
   procedure Object_Written (Replaced : in out Context; Source : Context) is
   begin
      Replaced := Source;
      pragma Assert (Valid (Replaced, F_A));
   end Object_Written;

   --  The callee was given the object to write: its fields are what the
   --  callee left, and the predicate says nothing of which are valid.
   procedure After_Callee (Passed : in out Context) is
   begin
      Renew (Passed);
      pragma Assert (Valid (Passed, F_A));
   end After_Callee;

   --  A callee that is not SPARK code is not taken to return the object
   --  satisfying its predicate.
   procedure After_Other_Code (Loose : in out Context)
     with SPARK_Mode => Off
   is
   begin
      Scramble (Loose);
      pragma Assert (Loose.Limit <= 1000);
   end After_Other_Code;

   --  Nor is a subprogram that is not SPARK code taken to be given its
   --  parameters satisfying theirs.
   procedure In_Other_Code (Free : Context) with SPARK_Mode => Off is
   begin
      pragma Assert (Free.Limit <= 1000);
   end In_Other_Code;

end Verification_Mutation_Predicates;

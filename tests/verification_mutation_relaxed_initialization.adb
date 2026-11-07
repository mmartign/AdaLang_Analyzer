package body Verification_Mutation_Relaxed_Initialization
  with SPARK_Mode
is
   function Relaxed_In (Carried : Arr) return Integer is
   begin
      return Carried (1);
   end Relaxed_In;

   procedure Copied (Dest : out Arr; Src : Arr; Value : out Integer) is
   begin
      Dest := Src;
      Value := Dest (1);
   end Copied;

   function Partial return Integer is
      Part : Arr with Relaxed_Initialization;
   begin
      Part (1) := 5;
      return Part (2);
   end Partial;

   procedure Partial_Assert is
      Sparse : Arr with Relaxed_Initialization;
   begin
      Sparse (1) := 1;
      pragma Assert (Sparse'Initialized);
   end Partial_Assert;

   procedure Fill_Bad (Unfilled : out Arr; From : Arr) is
   begin
      Unfilled := From;
   end Fill_Bad;

   function Pre_Or (Either : Arr; Flag : Boolean) return Integer is
   begin
      return Either (1);
   end Pre_Or;

   function Pre_Element (Front : Arr) return Integer is
   begin
      return Front (2);
   end Pre_Element;

   function Pre_Component (Holder : Rec) return Integer is
   begin
      return Holder.D;
   end Pre_Component;
end Verification_Mutation_Relaxed_Initialization;

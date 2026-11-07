package body Verification_Relaxed_Initialization
  with SPARK_Mode
is
   function Make return Arr is (others => 1);

   procedure Fill (Filled : out Arr) is
   begin
      Filled := Make;
   end Fill;

   procedure Whole_Assert is
      Whole : Arr with Relaxed_Initialization;
   begin
      Whole := (others => 0);
      pragma Assert (Whole'Initialized);
   end Whole_Assert;

   procedure Copy_Whole (Target : out Arr; Origin : Arr) is
   begin
      Target := Origin;
   end Copy_Whole;

   function Pre_Whole (Given : Arr) return Integer is
   begin
      return Given (1);
   end Pre_Whole;

   function Pre_Type (Typed : Rel) return Integer is
   begin
      return Typed (2);
   end Pre_Type;

   function Pre_Both (First, Second : Arr) return Integer is
   begin
      return Second (1) - First (1) / 2;
   end Pre_Both;

   function Assumed (Hoped : Arr) return Integer is
   begin
      pragma Assume (Hoped'Initialized);
      return Hoped (4);
   end Assumed;

   function Negated (Twice : Arr) return Integer is
   begin
      pragma Assume (not (not Twice'Initialized));
      return Twice (3);
   end Negated;

   procedure Scalar_In_Out (Counter : in out Soft_Int) is
   begin
      Counter := Counter + 1;
   end Scalar_In_Out;

   function Literal_Flags return Boolean is
      Set : constant Flags := (1 => True, others => False);
   begin
      return Set (1) = True;
   end Literal_Flags;
end Verification_Relaxed_Initialization;

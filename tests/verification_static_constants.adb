package body Verification_Static_Constants
  with SPARK_Mode
is
   procedure Ok_Divisor (X : Natural; Y : out Natural) is
   begin
      Y := X mod (Bits / 8);
      Y := Y + X / (Lane - 32);
   end Ok_Divisor;

   procedure Ok_Assert is
   begin
      pragma Assert (Bits = 64 and Bytes = 8 and Lane = 40);
   end Ok_Assert;

   --  Wrap is (300 mod 256) / 2 = 22, Top is 255.
   procedure Ok_Modular (Y : out Natural) is
   begin
      pragma Assert (Wrap = 22);
      pragma Assert (Top = 255);
      Y := 100 / (Bytes - 7);
   end Ok_Modular;

   procedure Ok_Index (A : in out Lanes) is
   begin
      A (Bits / 8 * 5) := 0;
   end Ok_Index;

   --  Counter is a variable, and From_Var has the value Counter had when
   --  the package was elaborated.
   procedure Bad_Variable (W : out Integer) is
   begin
      W := 10 / (Counter - 8);
   end Bad_Variable;

   procedure Bad_From_Variable (W : out Integer) is
   begin
      W := 10 / (From_Var - 8);
   end Bad_From_Variable;

   procedure Bad_Deferred (W : out Integer) is
   begin
      W := 10 / Hidden;
   end Bad_Deferred;

   procedure Bad_Modular is
   begin
      pragma Assert (Wrap = 150);
   end Bad_Modular;
end Verification_Static_Constants;

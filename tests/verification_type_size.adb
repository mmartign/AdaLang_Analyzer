package body Verification_Type_Size with SPARK_Mode is

   procedure Known is
   begin
      pragma Assert (Byte'Size = 8);
      pragma Assert (Verification_Type_Size.Byte'Size = 8);
      pragma Assert (Wide'Size = 64);
      pragma Assert (Decimal'Size = 4);
      pragma Assert (Percent'Size = 7);
      pragma Assert (Signed'Size = 4);
      pragma Assert (Stored'Size = 16);
      pragma Assert (Claused'Size = 24);
      pragma Assert (Colour'Size = 2);
      pragma Assert (Same'Size = 8);
      pragma Assert (Nibble'Size = 4);
      pragma Assert (Kept'Size = 16);
      pragma Assert (Cut'Size = 2);
      pragma Assert (Nothing'Size = 0);
      pragma Assert (Derived'Size = 16);
      pragma Assert (Tight'Size = 2);
      pragma Assert (Shorter'Size = 4);
      pragma Assert (Length'Size = 31);
      pragma Assert (Natural'Size = 31);
      pragma Assert (Integer'Size = 32);
      pragma Assert (Boolean'Size = 1);
   end Known;

   procedure Wrong is
   begin
      pragma Assert (Nibble'Size = 8);
      pragma Assert (Cut'Size = 16);
      pragma Assert (Percent'Size = 8);
      pragma Assert (Signed'Size = 3);
      pragma Assert (Shorter'Size = 7);
      pragma Assert (Decimal'Size = 8);
      pragma Assert (Positive'Size = 32);
      pragma Assert (Stored'Size = 7);
      pragma Assert (Tight'Size = 16);
   end Wrong;

   procedure Unknown (Item : Byte) is
   begin
      pragma Assert (Coded'Size = 1);
      pragma Assert (Warm'Size = 2);
      pragma Assert (Character'Size = 1);
      pragma Assert (Item'Size = 4);
   end Unknown;

   procedure Bytes (Bits : Natural; Count : out Natural) is
   begin
      Count := Bits / Byte'Size;
   end Bytes;

end Verification_Type_Size;

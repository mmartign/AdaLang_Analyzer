package body Verification_Generic_Narrow
  with SPARK_Mode
is
   function Spread (X : Natural) return Natural is
   begin
      return X mod (Bits / 8);
   end Spread;

   function Step (C : Count) return Count is
   begin
      return C + 1;
   end Step;
end Verification_Generic_Narrow;

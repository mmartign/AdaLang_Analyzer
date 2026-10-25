package body Verification_Generic_Inner
  with SPARK_Mode
is
   function Spread (X : Natural) return Natural is
   begin
      return X mod (Bits / 8);
   end Spread;
end Verification_Generic_Inner;

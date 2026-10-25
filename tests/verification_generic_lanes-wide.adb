package body Verification_Generic_Lanes.Wide
  with SPARK_Mode
is
   function Part (X : Natural) return Natural is
   begin
      return X / (Bits / 32);
   end Part;
end Verification_Generic_Lanes.Wide;

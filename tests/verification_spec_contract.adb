package body Verification_Spec_Contract with SPARK_Mode is

   function Sum (A, B : Small) return Integer is
   begin
      return A + B;
   end Sum;

end Verification_Spec_Contract;

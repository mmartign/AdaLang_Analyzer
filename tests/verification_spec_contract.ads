package Verification_Spec_Contract with SPARK_Mode is
   subtype Small is Integer range 0 .. 100;

   function Sum (A, B : Small) return Integer
     with Post => Sum'Result = A + B;
end Verification_Spec_Contract;

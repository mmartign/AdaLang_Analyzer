package body Verification_Mutation_Guaranteed_Operands with SPARK_Mode is

   function Total (Hour : Hours; Minute : Natural) return Millis is
   begin
      return (Millis (Hour) * In_Hour + Millis (Minute) * In_Minute) / 2;
   end Total;

end Verification_Mutation_Guaranteed_Operands;

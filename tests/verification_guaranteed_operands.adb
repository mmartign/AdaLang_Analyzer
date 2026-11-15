package body Verification_Guaranteed_Operands with SPARK_Mode is

   function Total (Hour : Hours; Minute : Minutes) return Millis is
   begin
      return Millis (Hour) * In_Hour + Millis (Minute) * In_Minute;
   end Total;

end Verification_Guaranteed_Operands;

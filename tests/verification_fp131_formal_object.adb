package body Verification_FP131_Formal_Object with SPARK_Mode is

   package body Formal is

      procedure Check_Whole is
      begin
         pragma Assert (not Whole'Constrained);
      end Check_Whole;

      procedure Check_Part is
      begin
         pragma Assert (not Outer.Part'Constrained);
      end Check_Part;

   end Formal;

end Verification_FP131_Formal_Object;

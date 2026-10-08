package body Verification_Named_Values with SPARK_Mode is

   procedure Same (Ctx : Context; Result : out Natural) is
   begin
      Result := Size (Ctx, Verification_Named_Values.F_B);
   end Same;

   procedure Other (Ctx : Context; Result : out Natural) is
   begin
      Result := Size (Ctx, Verification_Named_Values.F_C);
   end Other;

   procedure Literals (Fld, Copy : Field) is
   begin
      pragma Assert (Copy = Verification_Named_Values.F_B);
      pragma Assert (Copy /= Verification_Named_Values.F_C);
      pragma Assert (Copy = Verification_Named_Values.F_A);
   end Literals;

   procedure Numbers (Value, Small : Integer; Result : out Integer) is
   begin
      pragma Assert (Value < Limit);
      pragma Assert (Small < 3);
      Result := 100 / (Verification_Named_Values.Limit - Value);
   end Numbers;

   procedure Not_Numbers
     (Above, Middle, Exact : Integer; Octet : Byte; Result : out Integer) is
   begin
      pragma Assert (Above < Limit - 1);
      pragma Assert (Middle < 2);
      pragma Assert (Octet <= Wrapped);
      pragma Assert (Integer (Ratio) = 2);
      Result := 100 / (Exact - Limit + 1);
   end Not_Numbers;

end Verification_Named_Values;

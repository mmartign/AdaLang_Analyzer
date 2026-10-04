procedure Precision_Predefined_Numeric_Type_Clean is
   type Integer is range 0 .. 100;
   type Speed is digits 6 range 0.0 .. 300.0;
   X : Integer := 0;
   S : constant Speed := 1.0;
   B : constant Boolean := S > 0.0;
begin
   if B then
      X := X + 1;
   end if;
end Precision_Predefined_Numeric_Type_Clean;

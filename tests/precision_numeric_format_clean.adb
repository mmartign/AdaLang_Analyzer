procedure Precision_Numeric_Format_Clean is
   A : constant Integer := 1_000;
   B : constant Integer := 16#FF#;
   C : constant Integer := 2#1010_1010#;
   D : constant Float := 1.5E+3;
   E : constant Float := 12_345.678_9;
begin
   pragma Assert (A + B + C > 0 and then D > E);
end Precision_Numeric_Format_Clean;

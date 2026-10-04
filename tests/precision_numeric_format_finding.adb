procedure Precision_Numeric_Format_Finding is
   A : constant Integer := 1000;
   B : constant Integer := 16#ff#;
   C : constant Integer := 7#12#;
begin
   pragma Assert (A + B + C > 0);
end Precision_Numeric_Format_Finding;

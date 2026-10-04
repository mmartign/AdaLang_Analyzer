with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Explicit_Full_Discrete_Range_Clean is
   Count : Integer := 0;
begin
   for C in Colour loop
      Count := Count + 1;
   end loop;
   for C in Colour'First .. Green loop
      Count := Count + 1;
   end loop;
end Precision_Explicit_Full_Discrete_Range_Clean;

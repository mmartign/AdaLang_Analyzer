with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Explicit_Full_Discrete_Range_Finding is
   Count : Integer := 0;
begin
   for C in Colour'First .. Colour'Last loop
      Count := Count + 1;
   end loop;
end Precision_Explicit_Full_Discrete_Range_Finding;

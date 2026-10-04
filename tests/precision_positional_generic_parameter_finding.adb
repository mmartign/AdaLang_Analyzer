with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Positional_Generic_Parameter_Finding is
   package Ints is new Holder (Integer, 0);
begin
   Ints.Stored := 1;
end Precision_Positional_Generic_Parameter_Finding;

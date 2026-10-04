with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Pos_On_Enumeration_Type_Finding is
   N : constant Integer := Colour'Pos (Green);
begin
   pragma Assert (N = 1);
end Precision_Pos_On_Enumeration_Type_Finding;

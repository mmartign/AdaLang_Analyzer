with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Pos_On_Enumeration_Type_Clean is
   N : constant Integer := Integer'Pos (5);
   C : constant Colour := Colour'Succ (Red);
begin
   pragma Assert (N = 5 and then C = Green);
end Precision_Pos_On_Enumeration_Type_Clean;

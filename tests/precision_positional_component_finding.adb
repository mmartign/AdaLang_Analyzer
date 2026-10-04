with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Positional_Component_Finding is
   P : constant Point := (1, 2);
   T : constant Triple := (1, 2, 3);
begin
   pragma Assert (P.X = T (1));
end Precision_Positional_Component_Finding;

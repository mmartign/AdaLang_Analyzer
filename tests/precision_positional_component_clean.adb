with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Positional_Component_Clean is
   P : constant Point := Point'(X => 1, Y => 2);
   T : constant Triple := Triple'(1 => 1, 2 => 2, 3 => 3);
begin
   pragma Assert (P.X = T (T'First));
end Precision_Positional_Component_Clean;

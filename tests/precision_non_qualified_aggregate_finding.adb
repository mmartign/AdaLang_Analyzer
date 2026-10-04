with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Non_Qualified_Aggregate_Finding is
   P : constant Point := (X => 1, Y => 2);
begin
   pragma Assert (P.X = 1);
end Precision_Non_Qualified_Aggregate_Finding;

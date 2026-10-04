with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Fixed_Equality_Finding (A, B : in Money) is
   Same : constant Boolean := A = B;
begin
   pragma Assert (Same);
end Precision_Fixed_Equality_Finding;

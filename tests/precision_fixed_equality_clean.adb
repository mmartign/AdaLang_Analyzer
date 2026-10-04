with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Fixed_Equality_Clean (A, B : in Money; I, J : in Integer) is
   Close : constant Boolean := abs (A - B) < 0.05;
   Same  : constant Boolean := I = J;
begin
   pragma Assert (Close and then Same);
end Precision_Fixed_Equality_Clean;

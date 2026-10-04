with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Numeric_Indexing_Clean is
   T : Triple := Triple'(others => 0);
   function Twice (N : in Integer) return Integer is (2 * N);
begin
   T (T'First) := Twice (5);
end Precision_Numeric_Indexing_Clean;

function Precision_Identical_Case_Alternative_Expr_Nonadjacent_Clean
  (X : Integer) return Integer
is (case X is
       when 1 => 10,
       when 2 => 20,
       when others => 10);

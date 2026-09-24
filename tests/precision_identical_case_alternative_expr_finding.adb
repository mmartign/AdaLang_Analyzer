function Precision_Identical_Case_Alternative_Expr_Finding
  (X : Integer) return Integer
is (case X is
       when 1 => 10,
       when 2 => 10,
       when others => 0);

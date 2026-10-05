--  What is declared inside a subprogram and evaluated later -- a nested
--  expression function -- does not run in the state at its declaration
--  (FP-108). Divisor is one where Quotient is declared and zero where it is
--  called, and Guarded is called with Allowed false: neither division may
--  be proved, and neither is dead.
procedure Verification_Mutation_Deferred_Evaluation
  (Total : Integer; Result : out Integer)
  with SPARK_Mode
is
   Divisor : Integer := 1;
   Allowed : Boolean := True;

   function Quotient return Integer is (Total / Divisor);

   function Guarded return Integer
   is (if Allowed then 1 else Total / (Divisor - 1));
begin
   Divisor := 0;
   Allowed := Total > 0;
   Result := Quotient;
   Result := Guarded;
end Verification_Mutation_Deferred_Evaluation;

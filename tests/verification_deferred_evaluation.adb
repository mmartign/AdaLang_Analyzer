--  What is declared inside a subprogram and evaluated later -- a nested
--  expression function -- does not run in the state at its declaration
--  (FP-108). Divisor is zero where Quotient and Element are declared and
--  two where they are called: nothing divides by zero or indexes with it.
procedure Verification_Deferred_Evaluation
  (Total : Integer; Result : out Integer)
  with SPARK_Mode
is
   type Vector is array (1 .. 4) of Integer;

   Table   : constant Vector := (others => 1);
   Divisor : Integer := 0;

   function Quotient return Integer is (Total / Divisor);
   function Element return Integer is (Table (Divisor));
begin
   Divisor := 2;
   Result := Quotient;
   Result := Result / 2 + Element;
end Verification_Deferred_Evaluation;

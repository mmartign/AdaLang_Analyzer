--  At the same shape, the handler can run before the out parameter is set
--  when the assignment itself can raise (an element, a value its subtype
--  does not hold) or comes after a statement that can.
procedure Precision_Uninitialized_Output_Handler_After_Set_Finding
  (N : Natural; First : out Natural; Count : out Positive;
   Last : out Natural)
is
   A : array (1 .. 4) of Natural := [others => 0];
begin
   First := A (N);
   Count := 0;
   A (N) := 1;
   Last := 0;
exception
   when Constraint_Error =>
      null;
end Precision_Uninitialized_Output_Handler_After_Set_Finding;

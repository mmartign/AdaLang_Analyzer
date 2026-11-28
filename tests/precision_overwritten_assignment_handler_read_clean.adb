--  A flag set before statements that can raise and reset after them is
--  read by the exception handler when one does raise ("Locked := True;
--  <loop>; Locked := False;" with "if Locked then Release"; Ironclad's
--  Memory.MMU.Map_Range, FP-191).
procedure Precision_Overwritten_Assignment_Handler_Read_Clean
  (N : Natural; Ok : out Boolean)
is
   A      : array (1 .. 4) of Natural := [others => 0];
   Locked : Boolean := False;
   procedure Seize with Import, Convention => C, External_Name => "seize";
   procedure Release with Import, Convention => C, External_Name => "release";
begin
   Seize;
   Locked := True;
   for I in 1 .. N loop
      A (I) := I;
   end loop;
   Release;
   Locked := False;
   Ok := True;
exception
   when Constraint_Error =>
      if Locked then
         Release;
      end if;
      Ok := False;
end Precision_Overwritten_Assignment_Handler_Read_Clean;

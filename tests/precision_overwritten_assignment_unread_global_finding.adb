--  Overwritten_Assignment: an object of a package body that no body of the
--  package reads: a call of the program between two assignments to it does
--  not read it either (FP-175).

package body Precision_Overwritten_Assignment_Unread_Global_Finding is
   Full  : Boolean := True;
   Count : Natural := 0;

   procedure Tick is
   begin
      Count := Count + 1;
   end Tick;

   procedure Run is
   begin
      Full := False;
      Tick;
      Full := True;
   end Run;
end Precision_Overwritten_Assignment_Unread_Global_Finding;

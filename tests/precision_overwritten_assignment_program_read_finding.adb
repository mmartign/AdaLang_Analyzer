--  Overwritten_Assignment: the same object of a package body, read by a
--  subprogram of the package, but only a subprogram of the predefined
--  library runs between the two assignments: the first value is never
--  read (FP-175).

with Ada.Text_IO;

package body Precision_Overwritten_Assignment_Program_Read_Finding is
   Full  : Boolean := True;
   Count : Natural := 0;

   procedure Reader is
   begin
      if Full then
         Count := Count + 1;
      end if;
   end Reader;

   procedure Run is
   begin
      Full := False;
      Ada.Text_IO.Put_Line ("scanning");
      Full := True;
      Reader;
   end Run;
end Precision_Overwritten_Assignment_Program_Read_Finding;

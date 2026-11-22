--  Overwritten_Assignment: an object of a package body that a subprogram
--  of the package reads, directly, through another call, or in the tasks
--  it starts, is read by a call of that subprogram between two assignments
--  to it: Synth's "fullpop := False; parallel_deep_scan (...); fullpop :=
--  True;", whose scan tasks read fullpop (FP-175).

package body Precision_Overwritten_Assignment_Program_Read_Clean is
   Full  : Boolean := True;
   Count : Natural := 0;

   procedure Reader is
   begin
      if Full then
         Count := Count + 1;
      end if;
   end Reader;

   procedure Direct is
   begin
      Reader;
   end Direct;

   procedure Scan is
      task type Worker;
      task body Worker is
      begin
         Reader;
      end Worker;
      Workers : array (1 .. 2) of Worker;
   begin
      null;
   end Scan;

   procedure Run is
      procedure Through_Direct is
      begin
         Full := False;
         Direct;
         Full := True;
      end Through_Direct;

      procedure Through_Tasks is
      begin
         Full := False;
         Scan;
         Full := True;
      end Through_Tasks;
   begin
      Full := False;
      Reader;
      Full := True;
      Through_Direct;
      Through_Tasks;
   end Run;
end Precision_Overwritten_Assignment_Program_Read_Clean;

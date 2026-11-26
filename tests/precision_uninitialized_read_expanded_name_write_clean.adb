--  Uninitialized_Read: an assignment to an object named by an expanded
--  name writes the object, as one by its identifier does: through a
--  package declared in the subprogram (ayacc's "yy.action := ...",
--  zip-ada's "UnZ_Glob.compsize := ..."), through the subprogram's own
--  name, and with the target name "@" after a write (FP-177).

procedure Precision_Uninitialized_Read_Expanded_Name_Write_Clean
  (N : Integer; Code : out Integer)
is
   package Glob is
      Size  : Integer;
      Index : Integer;
   end Glob;

   Total : Integer;
begin
   Glob.Size := N;
   Precision_Uninitialized_Read_Expanded_Name_Write_Clean.Total := 1;
   Glob.Index := Glob.Size + Total;
   Glob.Index := @ + 1;
   Code := Glob.Index;
end Precision_Uninitialized_Read_Expanded_Name_Write_Clean;

--  Uninitialized_Read: at the same package declared in the subprogram, an
--  object read by its expanded name before any write, and one updated
--  with "@" before any write, are read with no value, which must be
--  reported (FP-177).

procedure Precision_Uninitialized_Read_Expanded_Name_Finding
  (N : Integer; Code : out Integer)
is
   package Glob is
      Size  : Integer;
      Count : Integer;
   end Glob;
begin
   Glob.Size := N;
   Code := Glob.Size + Glob.Count;
end Precision_Uninitialized_Read_Expanded_Name_Finding;

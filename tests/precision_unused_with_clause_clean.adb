with Ada.Text_IO;
with Ada.Strings.Unbounded;

procedure Precision_Unused_With_Clause_Clean is
   S : Ada.Strings.Unbounded.Unbounded_String :=
     Ada.Strings.Unbounded.To_Unbounded_String ("hi");
begin
   Ada.Text_IO.Put_Line (Ada.Strings.Unbounded.To_String (S));
end Precision_Unused_With_Clause_Clean;

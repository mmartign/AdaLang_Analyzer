--  Uninitialized_Output: an out parameter written through a renaming of it
--  (simple_components' Unbounded_Unsigneds) is not followed there, and so
--  not reported.

procedure Precision_Uninitialized_Output_Renamed_Clean (Borrow : out Integer) is
begin
   declare
      Result : Integer renames Borrow;
   begin
      Result := 1;
   end;
end Precision_Uninitialized_Output_Renamed_Clean;

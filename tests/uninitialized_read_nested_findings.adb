--  FP-146, FP-148: what the fixes for nested subprograms and loops leave
--  reported. Sum is read by the first iteration before any value; the
--  nested procedure Bump does not touch Count.
procedure Uninitialized_Read_Nested_Findings
  (N : Positive; Result : out Integer)
is
   Sum   : Integer;
   Count : Integer;
   Other : Integer := 0;
   procedure Bump is
   begin
      Other := Other + 1;
   end Bump;
begin
   for I in 1 .. N loop
      Sum := Sum + I;
   end loop;
   Bump;
   Result := Sum + Count + Other;
end Uninitialized_Read_Nested_Findings;

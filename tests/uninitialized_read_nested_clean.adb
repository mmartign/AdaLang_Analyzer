--  FP-146, FP-148 regression: reads that follow a write the walk did not
--  see, none of which is a read before any value.
procedure Uninitialized_Read_Nested_Clean (N : Positive; Result : out Integer)
is
   --  FP-146: a nested procedure the subprogram calls writes it first.
   Count : Integer;
   procedure Set is
   begin
      Count := 3;
   end Set;

   --  FP-146: through two nested procedures.
   Depth : Integer;
   procedure Inner is
   begin
      Depth := 1;
   end Inner;
   procedure Outer is
   begin
      Inner;
   end Outer;

   --  FP-146: an expression function reads it, and is called once a nested
   --  procedure has written it (Alire's Is_Valid_Choice).
   Chosen : Integer;
   function Twice return Integer is (Chosen * 2);
   procedure Choose (Value : Integer) is
   begin
      Chosen := Value;
   end Choose;

   --  FP-148: read under a guard in a loop that writes it later in its body,
   --  on an iteration after one that wrote it.
   Previous : Integer;
begin
   Set;
   Outer;
   Choose (Count);
   Result := Count + Depth + Twice;
   for I in 1 .. N loop
      if I > 1 then
         Result := Result + Previous;
      end if;
      Previous := I;
   end loop;
end Uninitialized_Read_Nested_Clean;

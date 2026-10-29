--  FP-132: a body declared in a block statement can read a variable of the
--  block, or of the subprogram, whenever it is called later in the block,
--  as one declared in the subprogram's declarative part can (FP-071).
procedure Precision_Dead_Store_Block_Nested_Body_Clean
  (N : Integer; Result : out Integer)
is
   Outer : Integer := 0;
begin
   declare
      Seen : Boolean := False;

      function Twice return Integer is
      begin
         return (if Seen then 2 * N else N);
      end Twice;
   begin
      if N > 0 then
         Seen := True;
      end if;
      Result := Twice;
   end;

   --  The body is in an inner block that encloses the assignment.
   declare
      function Plus return Integer is (Outer + N);
   begin
      Outer := 5;
      Result := Result + Plus;
   end;
end Precision_Dead_Store_Block_Nested_Body_Clean;

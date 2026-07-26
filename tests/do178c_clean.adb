--  do-178c: req LLR-DO178C-CLEAN-MAIN
procedure DO178C_Clean is

   --  do-178c: req LLR-DO178C-CLEAN-INCREMENT
   procedure Increment (Value : in out Integer)
     with Depends => (Value => Value)
   is
   begin
      Value := Value + 1;
   end Increment;

   Value : Integer := 0;
begin
   Increment (Value);

   --  A suppression used as certification evidence records why review
   --  accepted it.
   --  adalang-analyzer: ignore Null_Statement -- rationale: fixture syntax
end DO178C_Clean;

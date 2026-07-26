procedure DO178C_Findings is

   --  do-178c: req
   procedure Malformed_Trace is
   begin
      null;
   end Malformed_Trace;

begin
   --  adalang-analyzer: ignore Null_Statement
   Malformed_Trace;
end DO178C_Findings;

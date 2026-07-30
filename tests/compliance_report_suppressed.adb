--  do-178c: req LLR-COMPLIANCE-REPORT-MAIN
procedure Compliance_Report_Suppressed is
   X : Integer := 0;
begin
   X := X;  --  adalang-analyzer: ignore Self_Assignment -- rationale: fixture self-assignment
   if X = 0 then
      null;
   end if;
end Compliance_Report_Suppressed;

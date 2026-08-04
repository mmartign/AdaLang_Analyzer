procedure Non_Short_Circuit_Chain_Findings (A, B, C, D : Boolean) is
begin
   if A and B and C and D then
      null;
   end if;
end Non_Short_Circuit_Chain_Findings;

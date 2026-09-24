procedure Non_Short_Circuit_Positional_Call_Findings
  (C : Integer; X : out Integer)
is
   function Ok (V : Integer) return Boolean is (V > 0);
begin
   if not Ok (C) then
      X := 1;
   elsif C = 7 then
      X := 1;
   else
      X := 2;
   end if;
end Non_Short_Circuit_Positional_Call_Findings;

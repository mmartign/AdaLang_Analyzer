--  A while condition that nothing in the body can change keeps the value
--  it had on entry: it is constant.
procedure Precision_Constant_Condition_While_Unchanged_Finding
  (N : Integer; Count : out Integer)
is
   Flag : Boolean := True;
   I    : Integer := 0;
begin
   while Flag loop
      I := I + 1;
      exit when I > N;
   end loop;
   Count := I;
end Precision_Constant_Condition_While_Unchanged_Finding;

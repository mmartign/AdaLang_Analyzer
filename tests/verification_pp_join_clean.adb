--  Proof-path evidence: join sub-boundary. A fact established before a branch
--  survives an if/elsif/else merge and a case merge when every arm agrees,
--  and a branch predicate is available inside its own arm.
procedure Verification_PP_Join_Clean
  (X : Integer;
   Sel : Integer;
   Sink : out Integer)
with SPARK_Mode,
     Pre => X in 0 .. 10 and then Sel in 1 .. 3
is
   Y : Integer;
begin
   --  branch predicate carried into the arm
   if X > 5 then
      pragma Assert (X >= 6);
      Y := X;
   else
      pragma Assert (X <= 5);
      Y := 5;
   end if;

   --  fact about X survives the if/else merge
   pragma Assert (X >= 0);

   --  fact survives a case merge where every alternative agrees
   case Sel is
      when 1 => Y := X + 1;
      when 2 => Y := X + 2;
      when others => Y := X + 3;
   end case;
   pragma Assert (X <= 10);

   Sink := Y - Y + X;
end Verification_PP_Join_Clean;

procedure Verification_Symbolic_Loop (X : Integer)
  with SPARK_Mode,
       Pre => X <= 2_147_483_644
is
   I : Integer := 0;
   Y : Integer := X;
begin
   while I < 3 loop
      I := I + 1;
      Y := Y + 1;
   end loop;

   --  The bounded symbolic layer deliberately yields to widening at loops.
   pragma Assert (Y = X + 3);
end Verification_Symbolic_Loop;

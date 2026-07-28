procedure Verification_Symbolic_Join
  (X    : Integer;
   Flag : Boolean)
  with SPARK_Mode
is
   Y : Integer;
   Z : Integer;
begin
   if Flag then
      Y := X + 1;
      Z := X + 3;
   else
      Y := X + 2;
      Z := X + 3;
   end if;

   --  The identical symbolic assignment survives both predecessors.
   pragma Assert (Z = X + 3);

   --  This is true on only one predecessor. A merge must not retain it.
   pragma Assert (Y = X + 1);
end Verification_Symbolic_Join;

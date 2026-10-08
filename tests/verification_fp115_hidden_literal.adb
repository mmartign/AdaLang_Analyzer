--  FP-115: True and False are not reserved words. A parameter, an object
--  or a function may bear either name, and it then hides the literal: what
--  it holds is not what the name spells.
procedure Verification_FP115_Hidden_Literal
  (False : Boolean; Flag : Boolean; Result : out Integer)
  with SPARK_Mode
is
   True  : constant Boolean := Flag;
   Count : Integer := 0;
begin
   --  This is reached when the parameter is True, with Count at zero.
   if False then
      Result := 10 / Count;
   else
      Result := 0;
   end if;

   --  The constant is Flag, which may be False.
   pragma Assert (True);

   --  The parameter may be True.
   pragma Assert (not False);

   --  The literals themselves, named in full, are what they spell.
   pragma Assert (Standard.True);
   pragma Assert (not Standard.False);
end Verification_FP115_Hidden_Literal;

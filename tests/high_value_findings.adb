with Ada.Unchecked_Conversion;

--  Positive fixture for the safety, floating equality, and magic-number rules.
procedure High_Value_Findings is
   --  Named_Answer verifies that literals in named constants are exempt.
   Named_Answer : constant := 42;
   Left         : Float := 2.5;
   Right        : Float := 3.5;
   Value        : Integer := 99;

   --  This unsafe conversion is intentional test input.
   function To_Integer is new Ada.Unchecked_Conversion
     (Source => Float, Target => Integer);
begin
   --  Direct floating-point equality is intentionally reported.
   if Left = Right then
      Value := To_Integer (Left);
   end if;

   --  Integer equality and the literal -1 must remain clean.
   if Named_Answer = Value then
      Value := -1;
   end if;
end High_Value_Findings;

--  Proof-path evidence: scalar type sub-boundaries that must each reach
--  Proved_Safe -- signed integer, a statically bounded subtype, an
--  enumeration, and a modular type.
--  J is bounded above only through K, which interval narrowing cannot
--  represent, so its range check needs the solver; I has an interval of its
--  own from the membership test.
procedure Verification_PP_Types_Clean
  (I : Integer;
   J : Integer;
   K : Integer)
with SPARK_Mode,
     Pre => I in 0 .. 6 and then J >= 0 and then J <= K and then K <= 6
is
   subtype Small is Integer range 0 .. 10;
   type Level is (Low, Mid, High);
   type Byte is mod 256;

   S : Small;
   L : Level := Low;
   M : Byte := 0;
begin
   --  statically bounded subtype range check
   S := I + 1;
   pragma Assert (S <= 10);
   S := J + 1;

   --  enumeration comparison / membership
   L := High;
   pragma Assert (L = High);
   pragma Assert (L in Mid | High);

   --  modular arithmetic stays within the modulus
   M := M + 1;
   pragma Assert (M < 256);
end Verification_PP_Types_Clean;

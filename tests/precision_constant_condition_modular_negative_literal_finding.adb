--  Constant_Condition: at the same comparison with "-1", a modular object
--  whose value is known is or is not the type's last value, and a signed
--  one is or is not -1, whichever way "-1" is read: both conditions are
--  constant and must be reported (FP-176).

with Interfaces; use Interfaces;

procedure Precision_Constant_Condition_Modular_Negative_Literal_Finding
  (Code : out Integer)
is
   Selector : Unsigned_32;
   Level    : Integer;
begin
   Code := 0;
   Selector := 16#FFFF_FFFF#;
   Level := 0;
   if Selector = -1 then
      Code := 1;
   end if;
   if Level = -1 then
      Code := Code + 2;
   end if;
end Precision_Constant_Condition_Modular_Negative_Literal_Finding;

--  FP-100: computing Top's initial value always overflows, so the range
--  check against Natural that would follow is never reached. The overflow
--  is the one definite error on that declaration; a second one for the
--  range check was a false positive. Wide's initial value is computed
--  without overflow and is outside Small: that range check does fail.
procedure Verification_FP100_Overflow_Before_Range (Sink : out Integer) is
   function Ident (X : Integer) return Integer is (X);
   subtype Small is Integer range 0 .. 10;
   Top  : constant Natural := Ident (Integer'Last) + 1;
   Wide : constant Small := Ident (5) + 20;
begin
   Sink := Wide;
   if Top = 0 then
      Sink := 0;
   end if;
end Verification_FP100_Overflow_Before_Range;

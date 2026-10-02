--  FP-099: a function may have an "out" parameter, and a call to one in a
--  condition writes its actual. Found and Later are therefore not
--  uninitialized where they are read; reporting those reads as definite
--  errors was a false positive. Whether Decode writes them on every path is
--  not worked out, so the reads are not proved either. Never is passed to
--  nothing and is still a definite error.
procedure Verification_FP099_Function_Out_Actual
  (Code : Integer;
   Sink : out Character)
is
   function Decode
     (Value : Integer; Result : out Character) return Boolean is
   begin
      Result := 'a';
      return Value > 0;
   end Decode;

   Later : Character;
   Never   : Character;
begin
   Sink := ' ';
   for Step in 1 .. 3 loop
      declare
         Found : Character;
      begin
         if Decode (Code + Step, Found) then
            Sink := Found;
         end if;
      end;
   end loop;
   Sink := (if Decode (Code, Later) then Later else ' ');
   Sink := Never;
end Verification_FP099_Function_Out_Actual;

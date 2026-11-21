--  Repeated_Statement: an assignment repeated whose value calls only
--  functions that change no state, an instance of Unchecked_Conversion
--  (Ada_Drivers_Library's "To_Word") or a function whose body writes
--  nothing outside it, stores the same value twice.

with Ada.Unchecked_Conversion;
with Interfaces; use Interfaces;

function Precision_Repeated_Statement_Pure_Call_Finding
  (X : Integer_32) return Unsigned_32
is
   function To_Word is new Ada.Unchecked_Conversion (Integer_32, Unsigned_32);
   function Twice (V : Unsigned_32) return Unsigned_32 is
   begin
      return 2 * V;
   end Twice;
   W : Unsigned_32;
   T : Unsigned_32;
begin
   W := To_Word (X);
   W := To_Word (X);
   T := Twice (W);
   T := Twice (W);
   return T;
end Precision_Repeated_Statement_Pure_Call_Finding;

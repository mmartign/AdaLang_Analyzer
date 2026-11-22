--  FP-168: a nested function whose effects are not known (it calls one
--  that calls the imported Interfaces.Shift_Right) can still write an
--  up-level object of the subprogram it is declared in, here through the
--  nested function it calls in a declaration of its own: after the call
--  in the declaration of Tokens, Is_Valid is no longer known to have no
--  value (Excel_Writer's Write_as_Formula).

with Interfaces; use Interfaces;

procedure Verification_FP168_Unknown_Effects (Len : out Natural) is
   function High_Byte (N : Unsigned_16) return Unsigned_8 is
   begin
      return Unsigned_8 (Shift_Right (N, 8));
   end High_Byte;

   procedure Write (S : String; Is_Valid : out Boolean; Size : out Natural) is
      function Tokenize return Natural is
      begin
         Is_Valid := S'Length > 0;
         return S'Length;
      end Tokenize;

      function With_Size return Natural is
         N : constant Natural := Tokenize;
      begin
         return N + Natural (High_Byte (Unsigned_16 (N mod 256)));
      end With_Size;

      Tokens : constant Natural := With_Size;
   begin
      if Is_Valid then
         Size := Tokens;
      else
         Size := 0;
      end if;
   end Write;

   OK : Boolean;
begin
   Write ("=1+2", OK, Len);
end Verification_FP168_Unknown_Effects;

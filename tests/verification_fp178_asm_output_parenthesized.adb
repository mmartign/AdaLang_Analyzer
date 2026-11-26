--  FP-178: the object of T'Asm_Output is stored into, also in
--  parentheses (engine-3d's SVGA: "Unsigned_8'Asm_Output ("=q",
--  (result))"): Result is initialized where it is returned, and nothing
--  is a definite error.
with Interfaces; use Interfaces;
with System.Machine_Code; use System.Machine_Code;

function Verification_FP178_Asm_Output_Parenthesized
  (Offset : Integer) return Unsigned_8
is
   Result : Unsigned_8;
begin
   Asm (".byte 0x64; movb (%k1), %b0",
        Unsigned_8'Asm_Output ("=q", (Result)),
        Integer'Asm_Input ("r", Offset),
        Volatile => True);
   return Result;
end Verification_FP178_Asm_Output_Parenthesized;

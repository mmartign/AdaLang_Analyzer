--  Uninitialized_Read: the object of T'Asm_Output is stored into, also
--  when it is written in parentheses (engine-3d's SVGA Peek_Byte:
--  "Unsigned_8'Asm_Output ("=q", (result))", FP-178).

with Interfaces; use Interfaces;
with System.Machine_Code; use System.Machine_Code;

function Precision_Uninitialized_Read_Asm_Output_Parenthesized_Clean
  (Offset : Integer) return Unsigned_8
is
   Result : Unsigned_8;
begin
   Asm (".byte 0x64; movb (%k1), %b0",
        Unsigned_8'Asm_Output ("=q", (Result)),
        Integer'Asm_Input ("r", Offset),
        Volatile => True);
   return Result;
end Precision_Uninitialized_Read_Asm_Output_Parenthesized_Clean;

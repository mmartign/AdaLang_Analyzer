--  At the same shape, an object declared over another object is no write
--  of the out parameter.
with Interfaces; use Interfaces;
procedure Precision_Uninitialized_Output_Overlay_Finding
  (Source : String; Word : out Unsigned_32)
is
   Scratch : Unsigned_32;
   Bytes   : String (1 .. 4) with Import, Address => Scratch'Address;
begin
   Bytes := Source (Source'First .. Source'First + 3);
end Precision_Uninitialized_Output_Overlay_Finding;

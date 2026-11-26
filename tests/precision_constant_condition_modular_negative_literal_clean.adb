--  Constant_Condition: "-1" for a modular type is that type's "-" and
--  wraps to its last value, so a modular object can equal it. The C
--  function returns -1 as 16#FFFF_FFFF# (engine-3d's SVGA, "if
--  Video_Selector = -1 then"); none of these conditions is constant
--  (FP-176).

with Interfaces; use Interfaces;

procedure Precision_Constant_Condition_Modular_Negative_Literal_Clean
  (Code : out Integer)
is
   function Allocate (Number : Integer) return Unsigned_32;
   pragma Import (C, Allocate, "__dpmi_allocate_ldt_descriptors");

   Selector : Unsigned_32;
   Byte     : constant Unsigned_8 := Unsigned_8 (Allocate (2) mod 256);
begin
   Code := 0;
   Selector := Allocate (1);
   if Selector = -1 then
      Code := 1;
   end if;
   if Selector = Unsigned_32'(-1) then
      Code := Code + 2;
   end if;
   if Byte /= -(1) then
      Code := Code + 4;
   end if;
end Precision_Constant_Condition_Modular_Negative_Literal_Clean;

--  Repeated_Statement: an assignment repeated is no duplicate when its value
--  reads the target (a toggle twice clears the RP2040 PIO FIFOs; an indent
--  taken back twice) or calls a function (two bytes read, Zip-Ada).

with Interfaces; use Interfaces;

procedure Precision_Repeated_Statement_Effect_Clean
  (Flag : in out Boolean; Indent : in out Integer; B : out Unsigned_8)
is
   function Next_Byte return Unsigned_8
     with Import, Convention => C, External_Name => "next_byte";
begin
   Flag := Flag xor True;
   Flag := Flag xor True;
   Indent := Indent - 3;
   Indent := Indent - 3;
   B := Next_Byte;
   B := Next_Byte;
end Precision_Repeated_Statement_Effect_Clean;

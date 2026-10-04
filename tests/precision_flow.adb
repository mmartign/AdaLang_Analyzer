with Ada.Text_IO;

procedure Precision_Flow (Flag : in Boolean; Code : in Integer) is
   Local_Error : exception;
   Total : Integer := 0;

   procedure Compute (Value : in Integer; Result : out Integer) is
   begin
      Result := Value * 2;
   end Compute;

   function Twice (Value : in Integer) return Integer;
   pragma Inline (Twice);

   function Twice (Value : in Integer) return Integer is
   begin
      if Value > 0 then
         return Value * 2;
      end if;
      return 0;
   end Twice;

   function Search (Limit : in Integer) return Integer is
   begin
      for I in 1 .. Limit loop
         if I = Code then
            return I;
         end if;
      end loop;
      return 0;
   end Search;

   procedure Guarded is
   begin
      if Total > 3 then
         raise Local_Error;
      end if;
      Total := Total + 1;
   exception
      when Local_Error =>
         Ada.Text_IO.Put_Line ("failed");
   end Guarded;
begin
   if Flag then
      Total := Total + 1;
      Total := Total + Twice (Code);
   else
      return;
   end if;

   Total := Integer'Min (Total, 10) + Integer'Width + Code + Code * 2 + Code * 3
     + Code * 4 + Code * 5 + Code * 6 + Search (Total);
   Compute (Total, Total);
   Guarded;
   Ada.Text_IO.Put_Line (Integer'Image (Total));
end Precision_Flow;

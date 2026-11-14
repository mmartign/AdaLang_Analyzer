--  FP-144: Flag belongs to the enclosing procedure. Walk sets it, calls
--  itself, and restores it; the recursive call reads Flag through Look, a
--  procedure declared beside Walk, so the value set before the call is
--  read before it is overwritten and must not be flagged.
procedure Precision_Overwritten_Assignment_Up_Level_Read_Clean
  (N : Natural; Count : out Natural)
is
   Flag : Boolean := False;

   procedure Walk (Depth : Natural);

   procedure Look is
   begin
      if Flag then
         Count := Count + 1;
      end if;
   end Look;

   procedure Walk (Depth : Natural) is
   begin
      Look;
      if Depth > 0 then
         declare
            Saved : constant Boolean := Flag;
         begin
            Flag := True;
            Walk (Depth - 1);
            Flag := Saved;
         end;
      end if;
   end Walk;
begin
   Count := 0;
   Walk (N);
end Precision_Overwritten_Assignment_Up_Level_Read_Clean;

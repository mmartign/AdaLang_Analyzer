with Ada.Text_IO;

procedure Clean_Findings is
   A     : Integer := 1;
   Flag  : Boolean := True;
   Other : Boolean := False;
begin
   A := A + 2;
   A := A + 3;

   if Flag and then Other then
      Ada.Text_IO.Put_Line ("A B");
   else
      Ada.Text_IO.Put_Line ("AB");
   end if;

   while Flag loop
      A := A + 1;
   end loop;
end Clean_Findings;

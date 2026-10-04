with Ada.Text_IO;

procedure Precision_Declaration_In_Block_Clean is
   Total : Integer := 0;
begin
   begin
      Total := Total + 1;
   end;

   declare
      use Ada.Text_IO;
      pragma Warnings (Off);
   begin
      Put_Line ("x");
   end;

   declare
   begin
      Total := Total + 1;
   end;
end Precision_Declaration_In_Block_Clean;

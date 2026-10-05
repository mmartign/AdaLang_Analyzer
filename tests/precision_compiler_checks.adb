with Ada.Text_IO;
procedure Precision_Compiler_Checks is
   Spare : Integer;
   type Cell is access Integer;
   Item : Cell := new Integer'(1);
begin
    if Item.all=1 then
      null;
   end if;
end Precision_Compiler_Checks;

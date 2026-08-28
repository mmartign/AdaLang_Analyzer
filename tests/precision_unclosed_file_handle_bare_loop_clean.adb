with Ada.Text_IO;

procedure Precision_Unclosed_File_Handle_Bare_Loop_Clean
  (Some_Condition : Boolean)
is
   F : Ada.Text_IO.File_Type;
begin
   loop
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "input.txt");
      Ada.Text_IO.Close (F);
      if Some_Condition then
         return;
      end if;
   end loop;
end Precision_Unclosed_File_Handle_Bare_Loop_Clean;

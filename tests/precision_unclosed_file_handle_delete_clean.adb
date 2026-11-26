--  Unclosed_File_Handle: Delete closes the file it deletes (RM A.8.2:
--  "The given file is closed"). GWindows' Create_Desktop_Shortcut opens
--  the script it ran and deletes it (FP-180).

with Ada.Text_IO; use Ada.Text_IO;

procedure Precision_Unclosed_File_Handle_Delete_Clean (Script : String) is
   F : File_Type;
begin
   Open (F, In_File, Script);
   Delete (F);
end Precision_Unclosed_File_Handle_Delete_Clean;

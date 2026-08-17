with Ada.Text_IO; use Ada.Text_IO;
procedure Precision_Reraise_Discards_Occurrence_Bare_Raise_Clean is
   Bad_Input : exception;
begin
   raise Bad_Input;
exception
   when Bad_Input =>
      Put_Line ("logging");
      raise;
end Precision_Reraise_Discards_Occurrence_Bare_Raise_Clean;

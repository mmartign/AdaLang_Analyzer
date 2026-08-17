with Ada.Text_IO; use Ada.Text_IO;
procedure Precision_Reraise_Discards_Occurrence_Different_Exception_Clean is
   Bad_Input, Worse_Input : exception;
begin
   raise Bad_Input;
exception
   when Bad_Input =>
      Put_Line ("logging");
      raise Worse_Input;
end Precision_Reraise_Discards_Occurrence_Different_Exception_Clean;

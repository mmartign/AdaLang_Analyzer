procedure Precision_Overwritten_Assignment_Local_Early_Return_Finding
  (Flag : Boolean; Value : out Integer)
is
   Local : Integer;
begin
   Local := 0;
   if Flag then
      Value := 0;
      return;
   end if;
   Local := 1;
   Value := Local;
end Precision_Overwritten_Assignment_Local_Early_Return_Finding;

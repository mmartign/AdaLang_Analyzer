function Precision_Overwritten_Assignment_Early_Return_Clean
  (Text : String; Value : out Integer) return Boolean
is
begin
   Value := 0;
   if Text = "" then
      return False;
   end if;
   Value := Text'Length;
   return True;
end Precision_Overwritten_Assignment_Early_Return_Clean;

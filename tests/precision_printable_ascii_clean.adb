procedure Precision_Printable_Ascii_Clean is
   --  plain comment ~ with tilde
   S : constant String := "abc ~";
begin
   pragma Assert (S'Length = 5);
end Precision_Printable_Ascii_Clean;

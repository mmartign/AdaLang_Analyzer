package Precision_Parameters_Out_Of_Order_Clean is
   procedure Copy
     (Source : in Integer;
      Link   : access Integer;
      Both   : in out Integer;
      Target : out Integer;
      Scale  : in Integer := 1);
end Precision_Parameters_Out_Of_Order_Clean;

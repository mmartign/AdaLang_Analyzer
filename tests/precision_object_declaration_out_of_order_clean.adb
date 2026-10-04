package body Precision_Object_Declaration_Out_Of_Order_Clean is
   Counter : Integer := 0;

   procedure Bump is
   begin
      Counter := Counter + 1;
   end Bump;
end Precision_Object_Declaration_Out_Of_Order_Clean;

package body Precision_Uncommented_Begin_In_Package_Body_Clean is
   Counter : Integer := 0;

   procedure Bump is
      Step : constant Integer := 1;
   begin
      Counter := Counter + Step;
   end Bump;
begin -- Precision_Uncommented_Begin_In_Package_Body_Clean
   Counter := 1;
end Precision_Uncommented_Begin_In_Package_Body_Clean;

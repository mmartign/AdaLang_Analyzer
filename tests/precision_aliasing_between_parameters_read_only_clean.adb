procedure Precision_Aliasing_Between_Parameters_Read_Only_Clean is
   procedure Combine (A, B : in Integer) is
   begin
      null;
   end Combine;

   X : Integer := 1;
begin
   Combine (X, X);
end Precision_Aliasing_Between_Parameters_Read_Only_Clean;

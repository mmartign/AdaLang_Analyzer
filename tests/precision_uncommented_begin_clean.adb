procedure Precision_Uncommented_Begin_Clean is
   X : Integer := 0;

   procedure No_Declarations is
   begin
      X := 2;
   end No_Declarations;
begin -- Precision_Uncommented_Begin_Clean
   X := 1;
   No_Declarations;
end Precision_Uncommented_Begin_Clean;

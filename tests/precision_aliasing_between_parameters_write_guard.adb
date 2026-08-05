procedure Precision_Aliasing_Between_Parameters_Write_Guard is
   procedure Update (A : in out Integer; B : in Integer) is
   begin
      A := B;
   end Update;

   X : Integer := 1;
begin
   Update (X, X);
end Precision_Aliasing_Between_Parameters_Write_Guard;

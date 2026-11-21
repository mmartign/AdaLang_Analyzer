procedure Precision_Aliasing_Between_Parameters_Write_Guard is
   type Buffer is array (1 .. 4) of Integer;

   procedure Update (A : in out Buffer; B : in Buffer) is
   begin
      A (1) := B (2);
   end Update;

   X : Buffer := (others => 1);
begin
   Update (X, X);
end Precision_Aliasing_Between_Parameters_Write_Guard;

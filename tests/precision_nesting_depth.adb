procedure Precision_Nesting_Depth is
   generic
   package Outer is
      generic
      package Inner is
         Limit : constant Integer := 1;
      end Inner;
   end Outer;

   procedure Level_1 is
      procedure Level_2 is
         procedure Level_3 is
         begin
            null;
         end Level_3;
      begin
         Level_3;
      end Level_2;
   begin
      Level_2;
   end Level_1;
begin
   Level_1;
end Precision_Nesting_Depth;

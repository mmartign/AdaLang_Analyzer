package Precision_Global_Variable_Clean is
   Limit : constant Integer := 10;

   package Nested is
      Scratch : Integer := 0;
   end Nested;

   protected type Guard is
      procedure Bump;
   private
      Count : Integer := 0;
   end Guard;
end Precision_Global_Variable_Clean;

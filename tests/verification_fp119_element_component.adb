package body Verification_FP119_Element_Component with SPARK_Mode => On is

   --  Nothing relates the two elements: this fails for most arrays.
   procedure Two_Elements (Row : Items) is
   begin
      pragma Assert (Row (1).Count = Row (2).Count);
   end Two_Elements;

   --  The condition speaks of two elements and holds for many arrays, with
   --  a Limit of zero in the second among them: the division is reached.
   procedure Across_Elements (Mixed : Items; Share : Integer; Part : out Integer) is
   begin
      Part := 0;
      if Mixed (1).Limit = 14 and then Mixed (2).Limit < 13 then
         Part := Share / Mixed (2).Limit;
      end if;
   end Across_Elements;

   --  One element is itself.
   procedure One_Element (Same : Items) is
   begin
      pragma Assert (Same (1).Count = Same (1).Count);
   end One_Element;

end Verification_FP119_Element_Component;

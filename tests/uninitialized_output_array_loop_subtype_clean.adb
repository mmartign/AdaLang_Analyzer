procedure Uninitialized_Output_Array_Loop_Subtype_Clean is

   type Index_T is range 1 .. 3;
   type Triple is array (Index_T) of Integer;

   procedure Set_All (Arr : out Triple) is
   begin
      --  "for I in Index_T loop" iterates over the array's own index
      --  subtype directly (the shape seen in AdaCore/spark2014's Tokeneer
      --  example, auditlog.adb's SetFileDetails): every value of Index_T
      --  is visited, and each is written through Arr (I), so every
      --  element of Arr is written by the time the loop ends.
      for I in Index_T loop
         Arr (I) := 0;
      end loop;
   end Set_All;

begin
   null;
end Uninitialized_Output_Array_Loop_Subtype_Clean;

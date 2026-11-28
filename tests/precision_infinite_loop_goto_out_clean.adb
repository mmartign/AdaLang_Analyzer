--  A plain loop left by a goto to a label after it, or before it, has a
--  termination path (Ironclad's Devices.Partitions.Parse_GPT_Partitions,
--  "goto Return_End;", FP-197).
procedure Precision_Infinite_Loop_Goto_Out_Clean
  (Next : access function return Integer; Choice : out Integer)
is
   Tries : Natural := 0;
begin
   <<Again>>
   Tries := Tries + 1;
   loop
      Choice := Next.all;
      if Choice = 0 then
         goto Done;
      elsif Choice = 1 and then Tries < 3 then
         goto Again;
      end if;
   end loop;
   <<Done>>
   null;
end Precision_Infinite_Loop_Goto_Out_Clean;

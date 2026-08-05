procedure Precision_Select_Then_Abort_Finding is
   procedure Long_Running is
   begin
      null;
   end Long_Running;
begin
   select
      delay 1.0;
   then abort
      Long_Running;
   end select;
end Precision_Select_Then_Abort_Finding;

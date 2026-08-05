procedure Precision_Blocking_Protected_Finding is
   protected PO is
      procedure Wait;
   end PO;

   protected body PO is
      procedure Wait is
      begin
         delay 1.0;
      end Wait;
   end PO;
begin
   PO.Wait;
end Precision_Blocking_Protected_Finding;

procedure Precision_Select_Delay_Clean is
   task type Server is
      entry Request;
   end Server;

   task body Server is
   begin
      select
         accept Request;
      or
         delay 1.0;
      end select;
   end Server;

   S : Server;
begin
   null;
end Precision_Select_Delay_Clean;

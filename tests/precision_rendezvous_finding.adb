procedure Precision_Rendezvous_Finding is
   task type Server is
      entry Request;
   end Server;

   task body Server is
   begin
      accept Request;
   end Server;

   S : Server;
begin
   S.Request;
end Precision_Rendezvous_Finding;

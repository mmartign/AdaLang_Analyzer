procedure Precision_Requeue_Finding is
   protected Server is
      entry Slow_Path;
      entry Fast_Path;
   end Server;

   protected body Server is
      entry Slow_Path when True is
      begin
         requeue Fast_Path;
      end Slow_Path;

      entry Fast_Path when True is
      begin
         null;
      end Fast_Path;
   end Server;
begin
   Server.Slow_Path;
end Precision_Requeue_Finding;

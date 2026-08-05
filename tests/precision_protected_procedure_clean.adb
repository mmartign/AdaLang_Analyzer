procedure Precision_Protected_Procedure_Clean is
   protected Server is
      procedure Request;
   end Server;

   protected body Server is
      procedure Request is
      begin
         null;
      end Request;
   end Server;
begin
   Server.Request;
end Precision_Protected_Procedure_Clean;

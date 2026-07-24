--  A non-blocking call chain inside a protected operation must stay clean.
procedure Interprocedural_Blocking_Clean is
   procedure Work_Directly is
   begin
      null;
   end Work_Directly;

   procedure Work_Indirectly is
   begin
      Work_Directly;
   end Work_Indirectly;

   protected PO is
      procedure P;
   end PO;

   protected body PO is
      procedure P is
      begin
         Work_Indirectly;
      end P;
   end PO;
begin
   PO.P;
end Interprocedural_Blocking_Clean;

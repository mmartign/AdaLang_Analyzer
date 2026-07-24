--  A protected operation reaches a delay through two ordinary calls. The
--  summary fixed point must carry the blocking effect through both callees.
procedure Interprocedural_Blocking_Findings is
   procedure Wait_Directly is
   begin
      delay 0.01;
   end Wait_Directly;

   procedure Wait_Indirectly is
   begin
      Wait_Directly;
   end Wait_Indirectly;

   protected PO is
      procedure P;
   end PO;

   protected body PO is
      procedure P is
      begin
         Wait_Indirectly;
      end P;
   end PO;
begin
   PO.P;
end Interprocedural_Blocking_Findings;

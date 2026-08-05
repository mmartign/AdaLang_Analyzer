procedure Precision_Access_To_Subp_Finding is
   type Handler is access procedure (X : Integer);

   procedure Do_Nothing (X : Integer) is
   begin
      null;
   end Do_Nothing;

   H : Handler := Do_Nothing'Access;
begin
   H (1);
end Precision_Access_To_Subp_Finding;

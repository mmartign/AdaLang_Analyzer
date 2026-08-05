procedure Precision_No_Recursion_Indirect_Clean is
   procedure B (N : Integer);

   procedure A (N : Integer) is
   begin
      if N > 0 then
         B (N - 1);
      end if;
   end A;

   procedure B (N : Integer) is
   begin
      if N > 0 then
         A (N - 1);
      end if;
   end B;
begin
   A (5);
end Precision_No_Recursion_Indirect_Clean;

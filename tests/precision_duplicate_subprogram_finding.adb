procedure Precision_Duplicate_Subprogram_Finding is

   function Max_A (X, Y : Integer) return Integer is
   begin
      if X > Y then
         return X;
      else
         return Y;
      end if;
   end Max_A;

   function Max_B (X, Y : Integer) return Integer is
   begin
      if X > Y then
         return X;
      else
         return Y;
      end if;
   end Max_B;

begin
   null;
end Precision_Duplicate_Subprogram_Finding;

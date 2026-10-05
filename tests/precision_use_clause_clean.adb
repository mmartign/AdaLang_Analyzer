with Precision_Global_Pack;
procedure Precision_Use_Clause_Clean is
   type Count is range 0 .. 10;
   package Local is
      type Level is range 0 .. 5;
   end Local;
   use type Local.Level;
   use all type Count;
   L : Local.Level := 1;
begin
   L := L + 1;
   Precision_Global_Pack.I := Integer (L);
end Precision_Use_Clause_Clean;

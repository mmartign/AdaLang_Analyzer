package Precision_Global_Pack is
   I : Integer := 0;
   procedure External (X : Integer) with Import, Convention => C;
   procedure Available (X : in out Integer);
end Precision_Global_Pack;

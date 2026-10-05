package Precision_Inlining_Clean is
   procedure Q1 (I : in out Integer) with Inline => True;
   procedure Q2 (I : in out Integer) with Inline => True;
   procedure Q3 (I : in out Integer) with Inline => True;
   procedure Plain (I : in out Integer);
end Precision_Inlining_Clean;

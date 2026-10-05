package Precision_Inlining is
   procedure P1 (I : in out Integer) with Inline => True;
   procedure P2 (I : in out Integer) with Inline => True;
   procedure P3 (I : in out Integer) with Inline => True;
   procedure P4 (I : in out Integer) with Inline => True;
   procedure P5 (I : in out Integer);
   pragma Inline (P5);
   procedure Plain (I : in out Integer);
end Precision_Inlining;

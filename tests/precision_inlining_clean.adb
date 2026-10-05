package body Precision_Inlining_Clean is

   procedure Q1 (I : in out Integer) is
   begin
      Q2 (I);
   end Q1;

   procedure Q2 (I : in out Integer) is
   begin
      Q3 (I);
   end Q2;

   procedure Q3 (I : in out Integer) is
   begin
      I := I + 1;
   end Q3;

   procedure Plain (I : in out Integer) is
   begin
      Q1 (I);
      Plain (I);
   end Plain;

end Precision_Inlining_Clean;

package body Precision_Inlining is

   procedure Local (I : in out Integer) with Inline;

   procedure P1 (I : in out Integer) is
   begin
      I := I + 1;
      P2 (I);
   end P1;

   procedure P2 (I : in out Integer) is
   begin
      I := I + 1;
      P3 (I);
   end P2;

   procedure P3 (I : in out Integer) is
   begin
      I := I + 1;
      P4 (I);
   end P3;

   procedure P4 (I : in out Integer) is
   begin
      I := I + 1;
   end P4;

   procedure P5 (I : in out Integer) is
   begin
      P1 (I);
   end P5;

   procedure Local (I : in out Integer) is
   begin
      P5 (I);
   end Local;

   procedure Plain (I : in out Integer) is
   begin
      Local (I);
   end Plain;

end Precision_Inlining;

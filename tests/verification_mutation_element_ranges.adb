package body Verification_Mutation_Element_Ranges
  with SPARK_Mode
is
   procedure Narrow (X : Bytes; K : Index; S : out Small) is
   begin
      S := Small (X (K));
   end Narrow;

   procedure Wide (W : Wides; K : Index; S : out Small) is
   begin
      S := Small (W (K));
   end Wide;

   procedure Halved (Y : Bytes; K : Index; S : out Small) is
   begin
      S := Small (I64 (Y (K)) / 2);
   end Halved;

   procedure Not_SPARK (N : Bytes; K : Index; S : out Big)
     with SPARK_Mode => Off
   is
   begin
      S := Big (N (K));
   end Not_SPARK;
end Verification_Mutation_Element_Ranges;

package body Verification_Array_Contents
  with SPARK_Mode
is
   procedure Quantified (Q : Wides; K : Index; S : out Small) is
   begin
      S := Q (K);
   end Quantified;

   procedure Pointed (P : Wides; K : Index; S : out Small) is
   begin
      S := P (K);
   end Pointed;

   procedure Ranged (R : Arr; K : Integer; S : out Small) is
   begin
      S := R (K);
   end Ranged;

   procedure Shifted (H : Wides; I : Index; S : out Small) is
   begin
      S := H (I - 16);
   end Shifted;

   procedure Through (T : Wides; K : Index; S : out Small) is
   begin
      S := T (K);
   end Through;

   procedure Kept (E : in out Wides; K, J : Index) is
   begin
      E (J) := 200;
   end Kept;

   procedure Large (L : Arr; K : Integer; S : out Small) is
   begin
      S := L (K);
   end Large;

   procedure One_Based (O : From_One; K : Integer; S : out Small) is
   begin
      S := O (K);
   end One_Based;

   procedure Wrap (M : By_Mod; K : M8; S : out Small) is
   begin
      S := M (K + 2);
   end Wrap;

   procedure Field (F : Rec; K : Index; S : out Small) is
   begin
      S := F.A (K);
   end Field;

   procedure Other_Written (X, Y : in out Wides; K, J : Index; S : out Small)
   is
   begin
      Y (J) := 200;
      S := X (K);
   end Other_Written;

   procedure Flagged (Fl : Flags; V : Wides; K : Index; S : out Small) is
   begin
      S := V (K);
   end Flagged;

   procedure Asserted (A : Wides; K : Index) is
   begin
      pragma Assert (A (K) in 0 .. 100);
      pragma Assert (for some I in Index => A (I) <= 100);
   end Asserted;

   procedure Of_Normal (N : Normal; K : Index; S : out Small) is
   begin
      S := N (K);
   end Of_Normal;

   procedure Known_Normal (Nk : Normal; S : out Small) is
   begin
      S := Nk (3);
   end Known_Normal;

   procedure Of_Split (D : Split; K : Index; S : out Small) is
   begin
      S := D (K);
   end Of_Split;

   procedure Make (Z : out Normal) is
   begin
      Z := (others => 0);
   end Make;

   procedure After_Call (K : Index; S : out Small) is
      W : Wides;
   begin
      Make (W);
      S := W (K);
   end After_Call;
end Verification_Array_Contents;

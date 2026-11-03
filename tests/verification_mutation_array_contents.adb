package body Verification_Mutation_Array_Contents
  with SPARK_Mode
is
   procedure Written (Wr : in out Wides; K, J : Index; S : out Small) is
   begin
      Wr (J) := 200;
      S := Wr (K);
   end Written;

   procedure Other (Xo, Yo : Wides; K : Index; S : out Small) is
   begin
      S := Yo (K);
   end Other;

   procedure Looped (Lp : in out Wides; K : Index; S : out Small) is
   begin
      for I in Index loop
         Lp (I) := 200;
      end loop;
      S := Lp (K);
   end Looped;

   procedure Fill (Fo : out Wides) is
   begin
      Fo := (others => 200);
   end Fill;

   procedure Filled (Fi : in out Wides; K : Index; S : out Small) is
   begin
      Fill (Fi);
      S := Fi (K);
   end Filled;

   procedure Post_Bad (Pb : in out Wides; K : Index) is
   begin
      Pb (K) := 200;
   end Post_Bad;

   procedure Same_Index (Si : in out Wides; K, J : Index; S : out Small) is
   begin
      if J = K then
         Si (J) := 200;
      end if;
      S := Si (K);
   end Same_Index;

   procedure Part_Write (Pw : in out Wides; K : Index; S : out Small) is
   begin
      Pw (K + 1 .. 63) := (others => 200);
      S := Pw (K + 1);
   end Part_Write;

   procedure Ren (Rn : in out Wides; K : Index; S : out Small) is
      R : Wides renames Rn;
   begin
      R (K) := 200;
      S := Rn (K);
   end Ren;

   procedure In_Loop (Il : in out Wides; K : Index; S : out Small) is
   begin
      S := 0;
      for I in Index loop
         Il (I) := 200;
         S := Il (K);
      end loop;
   end In_Loop;

   procedure Set200 (V : out I64) is
   begin
      V := 200;
   end Set200;

   procedure Out_Element (Oe : in out Wides; K, J : Index; S : out Small) is
   begin
      Set200 (Oe (J));
      S := Oe (K);
   end Out_Element;

   procedure Rec_Write (Rw : in out Rec; K, J : Index; S : out Small) is
   begin
      Rw.A (J) := 200;
      S := Rw.A (K);
   end Rec_Write;

   procedure Clobber is
   begin
      G (3) := 200;
   end Clobber;

   procedure Global_Write (K : Index; S : out Small) is
   begin
      Clobber;
      S := G (K);
   end Global_Write;

   procedure Then_Assert (Ta : in out Wides; K, J : Index) is
   begin
      Ta (J) := 200;
      pragma Assert (Ta (K) in 0 .. 100);
   end Then_Assert;

   procedure Q0 (Y : A0; K : Integer) is null;

   procedure Sliding_Call (Sc : Arr; K : Integer) is
   begin
      Q0 (Sc, K);
   end Sliding_Call;

   procedure Written_Normal (Wn : in out Normal; K, J : Index; S : out Small)
   is
   begin
      Wn (K) := 200;
      S := Wn (J);
   end Written_Normal;

   procedure Plain (Pl : Wides; K : Index; S : out Small) is
   begin
      S := Pl (K);
   end Plain;
end Verification_Mutation_Array_Contents;

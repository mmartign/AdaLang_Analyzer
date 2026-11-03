package body Verification_Array_Stores
  with SPARK_Mode
is
   procedure Read_Back (A1 : in out Wides; I : Index; S : out Small) is
   begin
      A1 (I) := 5;
      S := A1 (I);
   end Read_Back;
   procedure Known_Back (A2 : in out Wides; S : out Small) is
   begin
      A2 (3) := 7;
      S := A2 (3);
   end Known_Back;
   procedure Kept_Other (A3 : in out Wides; J, K : Index; S : out Small)
   is
   begin
      A3 (J) := 5;
      S := A3 (K);
   end Kept_Other;
   procedure Increment (A4 : in out Wides; I : Index; S : out Small) is
   begin
      A4 (I) := A4 (I) + 1;
      S := A4 (I);
   end Increment;
   procedure Swap (A5 : in out Wides; I, J, K : Index; S : out Small) is
      T : constant I64 := A5 (I);
   begin
      A5 (I) := A5 (J);
      A5 (J) := T;
      S := A5 (K);
   end Swap;
   procedure In_Record (R6 : in out Rec; J, K : Index; S : out Small) is
   begin
      R6.A (J) := 5;
      S := R6.A (K);
   end In_Record;
   procedure Flag (F7 : in out Flags; J : Index) is
   begin
      F7 (J) := True;
      pragma Assert (F7 (J));
   end Flag;
   procedure Opaque_Value (A8 : in out Wides; J, K : Index; S : out Small)
   is
   begin
      A8 (J) := Opaque (3);
      S := A8 (K);
   end Opaque_Value;
   procedure Old_Kept (A9 : in out Wides; J, K : Index) is
   begin
      A9 (J) := 5;
   end Old_Kept;
   procedure Post_Inc (B1 : in out Wides; I : Index) is
   begin
      B1 (I) := B1 (I) + 1;
   end Post_Inc;
   procedure Others_Zero (G1 : out Wides; K : Index; S : out Small) is
   begin
      G1 := (others => 0);
      S := G1 (K);
   end Others_Zero;
   procedure Declared (K : Index; S : out Small) is
      G2 : constant Wides := (others => 7);
   begin
      S := G2 (K);
   end Declared;
   procedure Positional (K : Integer; S : out Small) is
      G3 : constant T4 := (1, 2, 3, 4);
   begin
      S := G3 (K);
   end Positional;
   procedure Named_Others (G4 : out Wides; K : Index; S : out Small) is
   begin
      G4 := (3 => 50, others => 1);
      S := G4 (K);
   end Named_Others;
   procedure Named_Cover (K : Integer; S : out Small) is
      G5 : constant T4 := (1 => 5, 2 => 6, 3 => 7, 4 => 8);
   begin
      S := G5 (K);
   end Named_Cover;
   procedure Copy (G6 : out Wides; Y6 : Wides; K : Index; S : out Small)
   is
   begin
      G6 := Y6;
      S := G6 (K);
   end Copy;
   procedure Update (G7 : in out Wides; J, K : Index; S : out Small) is
   begin
      G7 := G7'Update (J => 5);
      S := G7 (K);
   end Update;
   procedure Flag_Others (F9 : out Flags; K : Index) is
   begin
      F9 := (others => False);
      pragma Assert (not F9 (K));
   end Flag_Others;
   procedure Ranged (H1 : out Wides; K : Index; S : out Small) is
   begin
      H1 := (0 .. 9 => 5, others => 1);
      S := H1 (K);
   end Ranged;
   procedure Dynamic_Choice (H2 : out Wides; J : Index; S : out Small)
   is
   begin
      H2 := (J => 5, others => 200);
      S := H2 (J);
   end Dynamic_Choice;
   procedure Self (H3 : in out Wides; K : Index; S : out Small) is
   begin
      H3 := (others => H3 (0) + 1);
      S := H3 (K);
   end Self;
   procedure Same_Bounds (K : Integer; S : out Small) is
      Sx : Arr (1 .. 4) := (others => 9);
      Sy : Arr (1 .. 4);
   begin
      Sy := Sx;
      S := Sy (K);
   end Same_Bounds;
end Verification_Array_Stores;

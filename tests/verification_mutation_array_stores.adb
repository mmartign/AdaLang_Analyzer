package body Verification_Mutation_Array_Stores
  with SPARK_Mode
is
   procedure Last_Wins (C1 : in out Wides; J : Index; S : out Small) is
   begin
      C1 (J) := 5;
      C1 (J) := 200;
      S := C1 (J);
   end Last_Wins;
   procedure Maybe_Same (C2 : in out Wides; J, K : Index; S : out Small)
   is
   begin
      C2 (J) := 200;
      S := C2 (K);
   end Maybe_Same;
   procedure Self_Read (C3 : in out Wides; I, J : Index) is
   begin
      C3 (I) := C3 (J) + 1;
      pragma Assert (C3 (I) = C3 (J) + 1);
   end Self_Read;
   procedure Hidden_Index (C5 : in out Wides; J, K : Index; S : out Small)
   is
   begin
      C5 (Pick (J)) := 200;
      S := C5 (K);
   end Hidden_Index;
   procedure Other_Array (C6, D6 : in out Wides; I : Index; S : out Small)
   is
   begin
      C6 (I) := 5;
      S := D6 (I);
   end Other_Array;
   procedure Old_Changed (C7 : in out Wides; J, K : Index) is
   begin
      C7 (J) := 5;
   end Old_Changed;
   procedure Post_Wrong (C8 : in out Wides; I : Index) is
   begin
      C8 (I) := C8 (I) + 1;
   end Post_Wrong;
   procedure Swap_Wrong (C9 : in out Wides; I, J : Index) is
      T : constant I64 := C9 (I);
   begin
      C9 (I) := C9 (J);
      C9 (J) := T;
      pragma Assert (C9 (I) in 0 .. 100);
   end Swap_Wrong;
   procedure Slid_Named (S : out Small) is
      E1 : Arr (1 .. 3);
   begin
      E1 := (0 => 500, 1 => 0, 2 => 0);
      S := E1 (1);
   end Slid_Named;
   procedure Slid_Copy (Yc : Arr; K : Integer; S : out Small) is
      E2 : Arr (1 .. 4);
   begin
      E2 := Yc;
      S := E2 (K);
   end Slid_Copy;
   procedure Update_Bad (E3 : in out Wides; J : Index; S : out Small) is
   begin
      E3 := E3'Update (J => 200);
      S := E3 (J);
   end Update_Bad;
   procedure Others_Bad (E4 : out Wides; K : Index; S : out Small) is
   begin
      E4 := (others => 200);
      S := E4 (K);
   end Others_Bad;
   procedure Dynamic_Bad (E5 : out Wides; J, K : Index; S : out Small)
   is
   begin
      E5 := (J => 5, others => 200);
      S := E5 (K);
   end Dynamic_Bad;
   procedure Copy_Then_Write
     (E6 : out Wides; Y6 : Wides; K : Index; S : out Small) is
   begin
      E6 := Y6;
      E6 (K) := 200;
      S := E6 (K);
   end Copy_Then_Write;
   procedure Copy_Source_Written
     (E7 : out Wides; Y7 : in out Wides; K : Index; S : out Small) is
   begin
      E7 := Y7;
      Y7 (K) := 300;
      E7 (K) := Y7 (K);
      S := E7 (K);
   end Copy_Source_Written;
end Verification_Mutation_Array_Stores;

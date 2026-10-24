package body Verification_Element_Writes
  with SPARK_Mode
is
   procedure Ok_Carry (D : Product; R : out Limbs) is
      C : Integer;
      T : Any_Limb;
   begin
      R := (others => 0);
      R (0) := Integer (D (0) mod LM);
      C := Integer (D (0)) / LM;
      pragma Assert (C <= 610);
      T := Integer (D (1)) + C;
      R (1) := T mod LM;
   end Ok_Carry;

   --  A (0) is 1 after the write.
   procedure Bad_Same (A : in out Cells; W : out Integer) is
   begin
      A (0) := 1;
      W := 10 / (A (0) - 1);
   end Bad_Same;

   procedure Bad_Renaming (A : in out Cells; W : out Integer) is
      R : Cells renames A;
   begin
      R (0) := 1;
      W := 10 / (A (0) - 1);
   end Bad_Renaming;

   --  A and B can be one array.
   procedure Bad_Other_Name (A, B : in out Cells; W : out Integer)
     with SPARK_Mode => Off
   is
   begin
      B (0) := 1;
      W := 10 / (A (0) - 1);
   end Bad_Other_Name;
end Verification_Element_Writes;

package body Verification_FP141_Element_Symbols
  with SPARK_Mode
is
   procedure Bumped is
      Bump : Arr := (others => 5);
   begin
      Bump (2) := Bump (2) + 1;
      pragma Assert (Bump (2) = 6);
      pragma Assert (Bump (2) = 5);
   end Bumped;

   procedure Swapped is
      Swap : Arr := (1 => 1, 2 => 2, others => 0);
   begin
      Swap := (1 => Swap (2), 2 => Swap (1), 3 => 0, 4 => 0);
      pragma Assert (Swap (1) = 2);
      pragma Assert (Swap (1) = 1);
   end Swapped;

   procedure In_Record is
      Holder : Box := (C => (others => 5));
   begin
      Holder.C (2) := Holder.C (2) + 1;
      pragma Assert (Holder.C (2) = 6);
      pragma Assert (Holder.C (2) = 5);
   end In_Record;

   procedure Other_Index (I : Integer) is
      Wide : Arr := (others => 5);
   begin
      Wide (I) := Wide (3) + 1;
      pragma Assert (Wide (I) = 6);
      pragma Assert (Wide (3) = 5);
   end Other_Index;

   procedure Kept is
      Keep : Arr := (others => 5);
   begin
      Keep (2) := Keep (3) + 1;
      pragma Assert (Keep (3) = 5);
      pragma Assert (Keep (2) = 6);
   end Kept;
end Verification_FP141_Element_Symbols;

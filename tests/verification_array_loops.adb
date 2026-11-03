package body Verification_Array_Loops
  with SPARK_Mode
is
   procedure Zero (A : in out Arr) is
   begin
      for I in Index loop
         pragma Loop_Invariant
           (for all K in Index range 0 .. I - 1 => A (K) = 0);
         A (I) := 0;
      end loop;
   end Zero;

   procedure Normalize (A : Arr; R : out Arr; L : out Limb) is
   begin
      R := (others => 0);
      for I in Index loop
         R (I) := A (I) mod 65536;
         pragma Loop_Invariant
           (for all J in Index range 0 .. I => R (J) in Limb);
      end loop;
      pragma Assert (for all J in Index => R (J) in Limb);
      L := R (3);
   end Normalize;

   procedure Frame (A : in out Arr; S : out Small) is
   begin
      for I in Index range 0 .. 7 loop
         pragma Loop_Invariant
           (for all K in Index range I .. 15 => A (K) = A'Loop_Entry (K));
         A (I) := 1;
      end loop;
      S := A (12);
   end Frame;

   procedure Sum (A : Arr; T : out I32) is
   begin
      T := 0;
      for I in Index loop
         pragma Loop_Invariant (T in 0 .. 100 * I32 (I));
         T := T + A (I);
      end loop;
   end Sum;

   procedure Copy (A : Arr; B : out Arr; S : out Small) is
   begin
      B := (others => 0);
      for I in Index loop
         pragma Loop_Invariant (for all K in Index => B (K) in Small);
         B (I) := A (I);
      end loop;
      S := B (5);
   end Copy;

   procedure Keep (X : in out Small; Y : out Small) is
   begin
      Y := 0;
      for I in Index range 0 .. 7 loop
         pragma Loop_Invariant (X = X'Loop_Entry);
         Y := Small (I);
      end loop;
   end Keep;

   procedure Count (X : out I32) is
   begin
      X := 0;
      for I in Index loop
         pragma Loop_Invariant (X = I32 (I));
         X := X + 1;
      end loop;
   end Count;

   procedure Count_Down (X : out I32) is
   begin
      X := 15;
      for I in reverse Index loop
         pragma Loop_Invariant (X = I32 (I));
         X := I32 (I) - 1;
      end loop;
   end Count_Down;
end Verification_Array_Loops;

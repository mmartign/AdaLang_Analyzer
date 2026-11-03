package body Verification_Mutation_Array_Loops
  with SPARK_Mode
is
   procedure Zero_Bad (A : in out Arr) is
   begin
      for I in Index loop
         pragma Loop_Invariant (for all K in Index range 0 .. I => A (K) = 0);
         A (I) := 0;
      end loop;
   end Zero_Bad;

   procedure Frame_Bad (A : in out Arr; S : out Small) is
   begin
      for I in Index range 0 .. 7 loop
         pragma Loop_Invariant
           (for all K in Index range I .. 15 => A (K) in Small);
         A (I + 1) := 200;
      end loop;
      S := A (12);
   end Frame_Bad;

   procedure Entry_Bad (A : in out Arr) is
   begin
      for I in Index range 0 .. 7 loop
         pragma Loop_Invariant
           (for all K in Index => A (K) = A'Loop_Entry (K));
         A (I) := A (I) + 1;
      end loop;
   end Entry_Bad;

   procedure Set (A : in out Arr; I : Index) is
   begin
      A (I) := 500;
   end Set;

   procedure Call_Bad (A : in out Arr; S : out Small) is
   begin
      for I in Index range 0 .. 7 loop
         pragma Loop_Invariant
           (for all K in Index range 8 .. 15 => A (K) in Small);
         Set (A, I + 8);
      end loop;
      S := A (13);
   end Call_Bad;

   procedure After_Bad (A : in out Arr; S : out Small) is
   begin
      for I in Index range 0 .. 7 loop
         pragma Loop_Invariant
           (for all K in Index range 8 .. 15 => A (K) in Small);
         A (I) := 300;
      end loop;
      S := A (3);
   end After_Bad;

   procedure Cut_Bad (A : Arr; R : out Arr) is
   begin
      R := (others => 0);
      for I in Index loop
         R (I) := A (I) mod 1024;
         pragma Loop_Invariant
           (for all J in Index range 0 .. I => R (J) in 0 .. 1000);
      end loop;
   end Cut_Bad;

   procedure Ren_Bad (A : in out Arr; S : out Small) is
      B : Arr renames A;
   begin
      for I in Index range 0 .. 7 loop
         pragma Loop_Invariant
           (for all K in Index range 8 .. 15 => A (K) in Small);
         B (I + 8) := 300;
      end loop;
      S := A (14);
   end Ren_Bad;

   procedure Old_Bad_S (X : in out Small) is
   begin
      for I in Index loop
         X := Small (I);
      end loop;
   end Old_Bad_S;

   procedure Old_Bad_A (A : in out Arr) is
   begin
      for I in Index loop
         A (I) := 0;
      end loop;
   end Old_Bad_A;


   procedure Nested_Bad (A : in out Arr) is
   begin
      A (0) := 0;
      for J in Index range 0 .. 3 loop
         for I in Index range 1 .. 2 loop
            pragma Loop_Invariant (A'Loop_Entry (0) = 0);
            A (I) := 0;
         end loop;
         A (0) := I32 (J) + 1;
      end loop;
   end Nested_Bad;

   procedure Scalar_Bad (X : in out Small) is
   begin
      for I in Index range 0 .. 7 loop
         pragma Loop_Invariant (X = X'Loop_Entry);
         X := Small (I);
      end loop;
   end Scalar_Bad;

   procedure Empty_Bad (N : Index; X : out I32) is
   begin
      X := 0;
      for I in Index range 1 .. N loop
         pragma Loop_Invariant (X = I32 (I) - 1);
         X := I32 (I);
      end loop;
   end Empty_Bad;

   procedure Early_Bad (A : Arr; X : out I32) is
   begin
      X := 0;
      for I in Index loop
         exit when A (I) = 0;
         X := I32 (I);
      end loop;
   end Early_Bad;

   procedure After_Inv_Bad (X : out I32) is
   begin
      X := 0;
      for I in Index loop
         X := I32 (I);
         pragma Loop_Invariant (X = I32 (I));
         X := 0;
      end loop;
   end After_Inv_Bad;

   procedure Reverse_Bad (X : out I32) is
   begin
      X := 0;
      for I in reverse Index loop
         X := I32 (I);
      end loop;
   end Reverse_Bad;

   procedure Unproved_Inv_Bad (X : out I32) is
   begin
      X := 0;
      for I in Index loop
         pragma Loop_Invariant (X = 0);
         X := 1;
      end loop;
   end Unproved_Inv_Bad;
end Verification_Mutation_Array_Loops;

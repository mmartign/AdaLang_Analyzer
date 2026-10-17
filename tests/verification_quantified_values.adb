package body Verification_Quantified_Values is

   function Noisy (X : Integer) return Boolean is
   begin
      Calls := Calls + 1;
      return X > 0;
   end Noisy;

   procedure Effectful_Predicate is
      B : Boolean;
   begin
      Calls := 0;
      B := (for all I in 1 .. 3 => Noisy (I));
      pragma Assert (Calls = 0);
   end Effectful_Predicate;

   procedure Stale_Element is
      A : Arr := (others => 1);
   begin
      A (10) := -1;
      if (for all I in 1 .. 9 => A (I) > 0) then
         pragma Assert (A (10) > 0);
      end if;
   end Stale_Element;

   procedure Vacuous (N : Natural) is
      B : Boolean;
   begin
      B := (for all I in 1 .. N => False);
      pragma Assert (not B);
   end Vacuous;

   procedure Some_Found is
      A : Arr := (others => 0);
      B : Boolean;
   begin
      A (5) := 1;
      B := (for some I in 1 .. 10 => A (I) = 1);
      pragma Assert (not B);
   end Some_Found;

   procedure Nested_Same_Name is
      A : Arr := (others => 1);
      B : Boolean;
   begin
      A (2) := 0;
      B := (for all I in 1 .. 3 =>
              (for all I in 1 .. 1 => A (I) > 0) and then A (I) > 0);
      pragma Assert (B);
   end Nested_Same_Name;

   procedure Inside_Range (A : Arr; Last : Integer) is
      B : Boolean;
   begin
      B := (for all I in 1 .. Last => A (I) > 0);
      pragma Assert (Last <= 10);
   end Inside_Range;

   procedure Declared_Value (A : Arr) is
      Positive_First : constant Boolean := (for all E of A => E > 0);
   begin
      if Positive_First then
         pragma Assert (A (1) > 0);
      end if;
   end Declared_Value;

end Verification_Quantified_Values;

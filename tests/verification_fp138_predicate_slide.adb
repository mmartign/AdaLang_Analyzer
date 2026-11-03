package body Verification_FP138_Predicate_Slide
  with SPARK_Mode
is
   procedure Make (Y : out A0) is
   begin
      Y := (0 => 500, others => 0);
   end Make;

   procedure Known (S : out Small) is
      X : Arr (1 .. 4);
   begin
      Make (X);
      S := X (1);
   end Known;

   procedure Unknown (K : Integer; S : out Small) is
      U : Arr (1 .. 4);
   begin
      Make (U);
      S := U (K);
   end Unknown;

   procedure Same (K : Integer; S : out Small) is
      Z : Arr (0 .. 3);
   begin
      Make (Z);
      S := Z (K);
   end Same;
end Verification_FP138_Predicate_Slide;

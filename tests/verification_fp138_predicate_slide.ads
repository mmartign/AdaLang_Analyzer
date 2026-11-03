--  FP-138: an actual of an array subtype with other bounds than those of
--  the formal slides to them. The predicate of the formal's subtype, which
--  holds of the actual when the call returns, speaks of the elements at
--  the formal's indexes: Make (X) says X (2) .. X (4) are small, not X (1).
package Verification_FP138_Predicate_Slide
  with SPARK_Mode
is
   type I64 is range -2 ** 63 .. 2 ** 63 - 1;
   subtype Small is I64 range 0 .. 100;
   type Arr is array (Integer range <>) of I64;
   subtype A0 is Arr (0 .. 3)
     with Dynamic_Predicate => (for all I in 1 .. 3 => A0 (I) in 0 .. 100);

   procedure Make (Y : out A0);
   procedure Known (S : out Small);
   procedure Unknown (K : Integer; S : out Small) with Pre => K in 1 .. 2;
   procedure Same (K : Integer; S : out Small) with Pre => K in 1 .. 3;
end Verification_FP138_Predicate_Slide;

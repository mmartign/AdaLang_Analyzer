--  Arrays in loops: what the precondition says of an array the loop does
--  not write holds all through it; a quantified invariant over the
--  elements, at the start of the body or at its end, is proved and
--  assumed; X'Loop_Entry is the value X had where the loop was entered;
--  and where a loop over a range that is never empty is left by its head,
--  what holds is what holds at the end of its last iteration.
package Verification_Array_Loops
  with SPARK_Mode
is
   type I32 is range -2 ** 31 .. 2 ** 31 - 1;
   type Index is range 0 .. 15;
   type Arr is array (Index) of I32;
   subtype Small is I32 range 0 .. 100;
   subtype Limb is I32 range 0 .. 65535;

   procedure Zero (A : in out Arr)
     with Post => (for all K in Index => A (K) = 0);
   procedure Normalize (A : Arr; R : out Arr; L : out Limb)
     with Pre => (for all K in Index => A (K) in 0 .. 1000);
   procedure Frame (A : in out Arr; S : out Small)
     with Pre => (for all K in Index => A (K) in Small);
   procedure Sum (A : Arr; T : out I32)
     with Pre => (for all K in Index => A (K) in Small);
   procedure Copy (A : Arr; B : out Arr; S : out Small)
     with Pre => (for all K in Index => A (K) in Small);
   procedure Keep (X : in out Small; Y : out Small);
   procedure Count (X : out I32) with Post => X = 16;
   procedure Count_Down (X : out I32) with Post => X = -1;
end Verification_Array_Loops;

--  A loop or a block may have a name, and an exit may name the loop it
--  leaves: the innermost one of that name, however many loops it is in.
package Verification_Named_Loops with SPARK_Mode is

   --  The exit leaves both loops and goes past the assignment between
   --  their ends.
   procedure Skips_Outer_Body (Leave : Boolean; Result : out Integer);

   --  Every way out of the outer loop goes through that assignment.
   procedure Through_Outer_Body (Leave : Boolean; Result : out Integer);

   --  The exit that names the outer loop leaves the out parameter unset.
   procedure Leaves_Unset (Leave : Boolean; Unset_Result : out Integer);

   --  A name for the only loop, and a block with a name.
   procedure Only_Loop (Limit : Integer; Result : out Integer)
     with Pre => Limit in 1 .. 100;

   --  What the outer loop's body does after the inner loop is skipped by
   --  the exit, so the postcondition holds on one way only.
   procedure Posted (Leave : Boolean; Differs : out Integer)
     with Post => Differs = 2;

end Verification_Named_Loops;

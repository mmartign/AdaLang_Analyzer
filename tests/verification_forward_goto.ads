--  A goto to a label further down is one more way into that label: what
--  holds there is what holds on every way in.
package Verification_Forward_Goto with SPARK_Mode is

   --  The jump skips the assignment that makes the divisor nonzero.
   procedure Skips_Assignment (Taken : Boolean; Result : out Integer);

   --  Both ways into the label leave the divisor positive.
   procedure Both_Ways
     (Value : Integer; Taken : Boolean; Result : out Integer)
     with Pre => Value in 1 .. 10;

   --  What follows a jump is not reached.
   procedure Past_Dead_Code (Result : out Integer);

   --  The jump leaves the loop and goes past what follows it.
   procedure Out_Of_Loop (Result : out Integer);

   --  The jump skips an assertion, which is assumed on the other way only.
   procedure Skips_Assertion
     (Value : Integer; Taken : Boolean; Result : out Integer);

   --  The jump leaves the out parameter without a value.
   procedure Leaves_Unset (Taken : Boolean; Unset_Result : out Integer);

   --  The postcondition holds on both ways, or on one of them.
   procedure Posted (Taken : Boolean; Same : out Integer)
     with Post => Same = 2;

   procedure Posted_On_One_Way (Taken : Boolean; Differs : out Integer)
     with Post => Differs = 2;

   --  A jump to the end of a loop body skips what breaks the invariant,
   --  when it is taken.
   procedure Continues (Count : in out Integer; Taken : Boolean)
     with Pre => Count in 1 .. 10;

   --  A jump out of a handler.
   procedure From_Handler (Value : Integer; Result : out Integer);

end Verification_Forward_Goto;

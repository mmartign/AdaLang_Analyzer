--  What a procedure call leaves alone. A call whose effects are known --
--  from the callee's body or from its Global aspect -- changes the objects
--  it is given to write and the ones declared outside the caller; what is
--  known of the caller's other scalars still holds after it.
package Verification_Call_Frame with SPARK_Mode is

   Total : Natural := 0;

   procedure Log (Value : Natural) with Global => (In_Out => Total);
   procedure Fetch (Item : out Natural) with Global => null;

   procedure Kept (Length : Natural) with Pre => Length <= 1000;
   procedure Kept_In_Loop (Length : Natural) with Pre => Length <= 1000;

end Verification_Call_Frame;

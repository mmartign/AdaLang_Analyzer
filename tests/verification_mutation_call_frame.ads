--  Calls that change what a fact was about: the object is one the call
--  writes, is declared outside the caller, or is reached by a callee
--  declared inside it; or nothing is known of what the callee does.
--  None of the assertions and postconditions named in the mutation
--  manifest holds.
package Verification_Mutation_Call_Frame with SPARK_Mode is

   type Box is record
      Value : Natural := 0;
   end record;

   Total : Natural := 0;

   procedure Log (Value : Natural) with Global => (In_Out => Total);
   procedure Fetch (Item : out Natural) with Global => null;
   procedure Refill (Target : in out Box) with Global => null;
   procedure Drop (Value : in out Natural) with Global => null;
   procedure External with Import, Convention => C;

   procedure Actual_Written (Size : Natural) with Pre => Size <= 1000;
   procedure Global_Written;
   procedure Local_Reached;
   procedure Effects_Unknown;
   procedure Component_Written (Held_Box : in out Box);
   procedure Lowered (Level : in out Natural)
     with Pre => Level > 5, Post => Level > 5;

end Verification_Mutation_Call_Frame;

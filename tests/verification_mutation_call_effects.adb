--  Calls that change the state a proof was about.
--
--  A function called in a condition changes an object after the same
--  condition has tested it: what the test established no longer holds
--  where the condition has its value (FP-109). A call in a loop body
--  changes the object the loop invariant speaks of: the invariant is not
--  preserved on the strength of what held before the call (FP-111).
--  Nothing here is to be proved.
procedure Verification_Mutation_Call_Effects is

   Operand, Branched, Asserted, Grouped, Guarded : Integer := 1;
   Level : Integer := 10;

   function Clear return Boolean is
   begin
      Operand := 0;
      Branched := 0;
      Asserted := 0;
      Grouped := 0;
      Guarded := 0;
      return True;
   end Clear;

   procedure Lower (Value : in out Integer) is
   begin
      Value := Value - 5;
   end Lower;

   function Drain return Integer is
   begin
      Level := Level - 5;
      return Level;
   end Drain;

   function In_Operand return Integer is
   begin
      if Operand > 0 and then Clear and then 10 / Operand > 1 then
         return 1;
      end if;
      return 0;
   end In_Operand;

   function In_Branch return Integer is
   begin
      if Branched > 0 and then Clear then
         return 10 / Branched;
      end if;
      return 0;
   end In_Branch;

   function After_Assertion return Integer is
   begin
      pragma Assert (Asserted > 0 and then Clear);
      return 10 / Asserted;
   end After_Assertion;

   function In_Group return Integer is
   begin
      if Grouped > 0 and then (Clear and then 10 / Grouped > 1) then
         return 1;
      end if;
      return 0;
   end In_Group;

   function In_Loop return Integer is
      Total : Integer := 0;
   begin
      while Guarded > 0 and then Clear loop
         Total := 10 / Guarded;
      end loop;
      return Total;
   end In_Loop;

   procedure By_Procedure (Kept : in out Integer)
     with Pre => Kept > 0
   is
   begin
      for Round in 1 .. 3 loop
         pragma Loop_Invariant (Kept > 0);
         Lower (Kept);
      end loop;
   end By_Procedure;

   procedure By_Function (Last : out Integer)
     with Pre => Level > 0
   is
   begin
      Last := 0;
      for Round in 1 .. 3 loop
         pragma Loop_Invariant (Level > 0);
         Last := Drain;
      end loop;
   end By_Function;

   procedure By_Condition (Count : in out Integer)
     with Pre => Level >= 1
   is
   begin
      for Round in 1 .. 3 loop
         pragma Loop_Invariant (Level >= 1);
         if Drain > 100 then
            Count := 0;
         end if;
      end loop;
   end By_Condition;

   Result : Integer;
   Kept   : Integer := 3;
begin
   Result := In_Operand + In_Branch + After_Assertion + In_Group + In_Loop;
   By_Procedure (Kept);
   By_Function (Result);
   By_Condition (Result);
   pragma Unreferenced (Result);
end Verification_Mutation_Call_Effects;

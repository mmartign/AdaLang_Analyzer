--  A precondition is evaluated where the call is, so what the caller knows
--  about a global it reads applies. The callee's formals are its own: on a
--  recursive call they are the names the caller's state describes, and
--  must take the actuals' values, not keep the caller's.
package body Verification_Precondition_Globals with SPARK_Mode is
   procedure Needs_Above (X : Integer) is null;

   procedure Count_Down (X : Integer) is
   begin
      if X > 1 then
         Count_Down (X - 1);
      end if;
      Count_Down (X - X);
   end Count_Down;

   procedure Calls (N : Integer) is
   begin
      Level := 5;
      Needs_Above (4);
      Level := 5;
      Needs_Above (5);
      Level := N;
      Needs_Above (3);
   end Calls;
end Verification_Precondition_Globals;

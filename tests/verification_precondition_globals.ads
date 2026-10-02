--  Preconditions that read a global, and a recursive call (see the body).
package Verification_Precondition_Globals with SPARK_Mode is
   Level : Integer := 0;

   procedure Needs_Above (X : Integer) with Pre => Level > X;
   procedure Count_Down (X : Integer) with Pre => X > 0;
   procedure Calls (N : Integer);
end Verification_Precondition_Globals;

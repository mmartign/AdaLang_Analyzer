--  Instances of generic subprograms inside the verified subset. What an
--  instance does is not followed: a call to one is the call of a
--  subprogram whose effects are not known, and it reaches the objects of
--  the subprogram that declares it through the subprograms and objects
--  given for its formals. The actuals of an instance are evaluated where
--  it is declared. Each assertion of Formal_Procedure,
--  Formal_Procedure_Parameter, Formal_Object_Copied, Formal_Object_Renamed,
--  Two_Instances and Actual_Evaluated fails at run time. The others hold.
package Verification_Generic_Instances is

   Calls : Integer := 0;
   function Count (X : Integer) return Integer;

   generic
      with procedure Action;
   procedure Run with Global => null;

   generic
      with procedure Action (V : in out Integer);
   procedure Apply (X : in out Integer) with Global => null;

   generic
      Value : Integer;
   procedure Set (X : out Integer) with Global => null, Post => X = Value;

   generic
      V : in out Integer;
   procedure Inc with Pre => V < 1000, Post => V = V'Old + 1;

   procedure Formal_Procedure;
   procedure Formal_Procedure_Parameter;
   procedure Formal_Object_Copied;
   procedure Formal_Object_Renamed;
   procedure Two_Instances;
   procedure Actual_Evaluated;
   procedure Before_The_Call (X : Integer) with Pre => X > 0;

end Verification_Generic_Instances;

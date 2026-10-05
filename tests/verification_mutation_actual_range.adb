--  Actual parameters that may not fit the subtype of their formal, and
--  values given back that may not fit the subtype of the actual. None of
--  the checks below may be proved.
procedure Verification_Mutation_Actual_Range
  with SPARK_Mode
is
   subtype Small is Integer range 1 .. 10;
   subtype Tiny is Integer range 1 .. 5;

   Sink : Integer := 0;

   --  The trivial preconditions make GNATprove check each subprogram on its
   --  own: at the calls below the values happen to fit.

   procedure Take (Formal : Small)
     with Pre => True, Global => (In_Out => Sink);
   procedure Take (Formal : Small) is
   begin
      Sink := Formal;
   end Take;

   function Twice (Formal : Small) return Integer is (Formal * 2)
     with Pre => True;

   procedure Give (Formal : out Small)
     with Pre => True;
   procedure Give (Formal : out Small) is
   begin
      Formal := 7;
   end Give;

   --  Nothing bounds the actual.
   procedure Unbounded (Any : Integer)
     with Pre => True;
   procedure Unbounded (Any : Integer) is
   begin
      Take (Any);
   end Unbounded;

   --  The precondition bounds it on one side only.
   procedure Half_Bounded (Positive_Only : Integer)
     with Pre => Positive_Only >= 1;
   procedure Half_Bounded (Positive_Only : Integer) is
   begin
      Take (Positive_Only);
   end Half_Bounded;

   --  The expression leaves the formal's subtype for the last value.
   procedure Computed (Last : Small)
     with Pre => True;
   procedure Computed (Last : Small) is
   begin
      Take (Last + 1);
   end Computed;

   --  The actual of a function call in an expression.
   function In_Expression (Loose : Integer) return Integer
   is (Twice (Loose))
     with Pre => True;

   --  The guard is on another object.
   procedure Misguarded (Passed, Tested : Integer)
     with Pre => True;
   procedure Misguarded (Passed, Tested : Integer) is
   begin
      if Tested in 1 .. 10 then
         Take (Passed);
      end if;
   end Misguarded;

   --  What the callee gives back may not fit a narrower actual.
   procedure Receive (Narrow : out Tiny)
     with Pre => True;
   procedure Receive (Narrow : out Tiny) is
   begin
      Give (Narrow);
   end Receive;

   Value : Integer := 3;
   Small_Value : Tiny := 2;
begin
   Unbounded (Value);
   Half_Bounded (Value);
   Computed (Value);
   Sink := In_Expression (Value);
   Misguarded (Value, Value);
   Receive (Small_Value);
end Verification_Mutation_Actual_Range;

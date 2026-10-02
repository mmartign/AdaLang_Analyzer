--  A call that resolves to a completion -- a null procedure or an
--  expression function in the body -- is still checked against the
--  precondition written on the declaration in the spec, with the actuals
--  bound to that declaration's formals whatever order they are named in.
package body Verification_Null_Completion_Contracts with SPARK_Mode is
   procedure Needs_Positive (X : Integer) is null;
   procedure Needs_Ordered (Low : Integer; High : Integer) is null;
   function Half (X : Integer) return Integer is (X / 2);

   procedure Calls (N : Integer; Sink : out Integer) is
   begin
      Needs_Positive (7);
      Needs_Positive (N - N);
      Needs_Positive (N);
      Needs_Ordered (1, 2);
      Needs_Ordered (High => 1, Low => 2);
      Sink := Half (4);
      Sink := Half (1);
   end Calls;
end Verification_Null_Completion_Contracts;

--  Contracts on declarations completed by a null procedure or an
--  expression function (see the body).
package Verification_Null_Completion_Contracts with SPARK_Mode is
   procedure Needs_Positive (X : Integer) with Pre => X > 0;
   procedure Needs_Ordered (Low : Integer; High : Integer)
     with Pre => Low > 0 and then High > Low;
   function Half (X : Integer) return Integer with Pre => X >= 2;
   procedure Calls (N : Integer; Sink : out Integer);
end Verification_Null_Completion_Contracts;

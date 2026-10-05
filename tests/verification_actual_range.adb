--  The value of an actual parameter must fit the subtype of its formal, and
--  what the callee leaves in an "out" or "in out" parameter must fit the
--  subtype of the actual. Each check below holds.
procedure Verification_Actual_Range
  with SPARK_Mode
is
   subtype Small is Integer range 1 .. 10;
   subtype Tiny is Integer range 1 .. 5;

   Sink : Integer := 0;

   --  The trivial preconditions make GNATprove check each subprogram on its
   --  own.

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

   --  A value of a wider subtype, bounded by the precondition.
   procedure Wider (Bounded : Integer)
     with Pre => Bounded in 1 .. 10;
   procedure Wider (Bounded : Integer) is
   begin
      Take (Bounded);
   end Wider;

   --  An expression that stays inside the formal's subtype.
   procedure Computed (Below : Small)
     with Pre => Below < 10;
   procedure Computed (Below : Small) is
   begin
      Take (Below + 1);
   end Computed;

   --  A named association.
   procedure Named (Chosen : Integer)
     with Pre => Chosen in 1 .. 10;
   procedure Named (Chosen : Integer) is
   begin
      Take (Formal => Chosen);
   end Named;

   --  A guarded actual.
   procedure Guarded (Tested : Integer)
     with Pre => True;
   procedure Guarded (Tested : Integer) is
   begin
      if Tested in 1 .. 10 then
         Take (Tested);
      end if;
   end Guarded;

   --  The actual of a function call in an expression.
   function In_Expression (Operand : Integer) return Integer
   is (Twice (Operand))
     with Pre => Operand in 1 .. 10;

   --  What the callee gives back fits a wider actual.
   procedure Receive (Wide : out Integer)
     with Pre => True;
   procedure Receive (Wide : out Integer) is
   begin
      Give (Wide);
   end Receive;

   --  A narrower actual needs no check on the way in.
   procedure Narrower (Fits : Tiny)
     with Pre => True;
   procedure Narrower (Fits : Tiny) is
   begin
      Take (Fits);
   end Narrower;

   Value : Integer := 3;
   Five  : constant Tiny := 2;
begin
   Wider (Value);
   Computed (Value);
   Named (Value);
   Guarded (Value);
   Sink := In_Expression (Value);
   Receive (Value);
   Narrower (Five);
end Verification_Actual_Range;

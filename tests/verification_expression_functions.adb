--  An expression function is verified as a subprogram: its expression is
--  checked from the subtypes of its parameters and what its precondition
--  says. The checks inside a precondition and a postcondition are
--  obligations too, the first on entry, the second at the exit. Each check
--  below holds.
procedure Verification_Expression_Functions
  with SPARK_Mode
is
   subtype Small is Integer range 1 .. 10;
   type Vector is array (1 .. 4) of Integer;

   Table : constant Vector := (others => 1);

   function Half (Value : Small) return Integer is (Value / 2);

   function Ratio (Total, Divisor : Integer) return Integer
   is (Total / Divisor)
     with Pre => Divisor > 0 and then Total >= 0;

   function Element (Position : Integer) return Integer
   is (Table (Position))
     with Pre => Position in 1 .. 4;

   function Chained (Bounded : Integer) return Integer
   is (Half (Bounded))
     with Pre => Bounded in 1 .. 10;

   function Needs (Positive_Value : Integer) return Boolean
   is (Positive_Value > 3)
     with Pre => Positive_Value > 0;

   --  The call in the precondition is guarded by what stands before it;
   --  the one in the postcondition by the precondition.
   procedure Use_It (Value : Integer; Result : out Integer)
     with Pre  => Value > 0 and then Needs (Value),
          Post => Result = Ratio (Value, 2)
   is
   begin
      Result := Ratio (Value, 2);
   end Use_It;

   Outcome : Integer;
begin
   Use_It (8, Outcome);
   Outcome := Outcome + Element (2) + Chained (4);
end Verification_Expression_Functions;

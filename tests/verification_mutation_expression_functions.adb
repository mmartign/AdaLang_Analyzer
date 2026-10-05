--  Expression functions and contracts whose checks nothing protects: the
--  precondition that would make them hold is missing. None of the checks
--  below may be proved.
procedure Verification_Mutation_Expression_Functions
  with SPARK_Mode
is
   subtype Small is Integer range 1 .. 10;
   type Vector is array (1 .. 4) of Integer;

   Table : constant Vector := (others => 1);

   function Half (Value : Small) return Integer is (Value / 2);

   --  Nothing excludes a zero divisor.
   function Ratio (Total, Unchecked : Integer) return Integer
   is (Total / Unchecked)
     with Pre => Total >= 0;

   --  Nothing bounds the index.
   function Element (Loose : Integer) return Integer
   is (Table (Loose))
     with Pre => True;

   --  Nothing bounds the actual.
   function Chained (Wide : Integer) return Integer
   is (Half (Wide))
     with Pre => True;

   function Needs (Positive_Value : Integer) return Boolean
   is (Positive_Value > 3)
     with Pre => Positive_Value > 0;

   --  The call in the precondition is not guarded.
   procedure Use_It (Unknown : Integer; Result : out Integer)
     with Pre => Needs (Unknown)
   is
   begin
      Result := Unknown;
   end Use_It;

   Outcome : Integer;
begin
   Use_It (8, Outcome);
   Outcome := Ratio (Outcome, 2) + Element (2) + Chained (4);
end Verification_Mutation_Expression_Functions;

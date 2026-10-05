--  Guards that do not protect the operand they stand before: each check
--  below can fail, so none may be proved, and none of the operands is dead.
procedure Verification_Mutation_Guarded_Operand
  with SPARK_Mode
is
   type Vector is array (1 .. 4) of Integer;

   Table : constant Vector := (others => 1);

   --  The trivial preconditions make GNATprove check each subprogram on
   --  its own: at the calls below the values happen to be safe.

   --  The guard admits zero.
   function Weak_Guard (Total : Natural; Admitted : Integer) return Boolean
   is (Admitted >= 0 and then Total / Admitted > 1)
     with Pre => True;

   --  The right operand of "or else" is evaluated where the left one is
   --  false, that is where Refused is not positive.
   function Wrong_Connective (Total : Natural; Refused : Integer)
      return Boolean
   is (Refused > 0 or else Total / Refused > 1)
     with Pre => True;

   --  The guard is on another object.
   function Other_Object (Unbound, Bound : Integer) return Integer
   is (if Bound in 1 .. 4 then Table (Unbound) else 0)
     with Pre => True;

   --  The elsif part is reached where its own condition holds and the
   --  first one does not; neither bounds Open above.
   function Open_Elsif (Open : Integer) return Integer
   is (if Open < 1 then 0 elsif Open > 0 then Table (Open) else 0)
     with Pre => True;

   --  The range 0 .. Runs is never empty, and Runs may be zero.
   procedure Loop_Runs (Total : Integer; Runs : Natural; Result : out Integer)
     with Pre => True
   is
   begin
      Result := 0;
      for Step in 0 .. Runs loop
         Result := Total / Runs;
      end loop;
   end Loop_Runs;

   --  The alternative is selected for zero too, which is not an index.
   procedure Wide_Alternative (Picked : Natural; Result : out Integer)
     with Pre => True
   is
   begin
      case Picked is
         when 0 .. 4 => Result := Table (Picked);
         when others => Result := 0;
      end case;
   end Wide_Alternative;

   Outcome : Integer;
   Seen    : Boolean;
begin
   Seen := Weak_Guard (6, 2);
   Seen := Seen and then Wrong_Connective (6, 2);
   Outcome := Other_Object (2, 3) + Open_Elsif (3);
   pragma Assert (Outcome <= 2);
   Loop_Runs (5, 2, Outcome);
   Wide_Alternative (2, Outcome);
   pragma Assert (Seen or else Outcome <= Integer'Last);
end Verification_Mutation_Guarded_Operand;

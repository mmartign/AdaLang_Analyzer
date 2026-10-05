--  A check on an operand that an expression evaluates only under a guard is
--  made where the guard holds: the right operand of a short-circuit form, a
--  dependent expression of an if or case expression. Where the guard is
--  known not to hold the operand is never evaluated, and neither is the body
--  of a loop over an empty range nor a case alternative that the selector
--  does not select (FP-106).
procedure Verification_Guarded_Operand
  with SPARK_Mode
is
   subtype Small is Integer range 1 .. 10;
   type Vector is array (1 .. 4) of Integer;

   Table : constant Vector := (others => 1);

   --  Guards that hold for some values. The trivial preconditions make
   --  GNATprove check each subprogram on its own.

   function Ratio_Above (Total : Natural; Divisor : Integer) return Boolean
   is (Divisor > 0 and then Total / Divisor > 1)
     with Pre => True;

   function Ratio_Or (Total : Natural; Quotient_By : Integer) return Boolean
   is (Quotient_By <= 0 or else Total / Quotient_By > 1)
     with Pre => True;

   function Element_Or_Zero (Position : Integer) return Integer
   is (if Position in 1 .. 4 then Table (Position) else 0)
     with Pre => True;

   function Chained (Place : Integer) return Integer
   is (if Place < 1 then 0 elsif Place <= 4 then Table (Place) else 0)
     with Pre => True;

   function Converted (Value : Integer) return Boolean
   is (Value in 1 .. 10 and then Small (Value) = 3)
     with Pre => True;

   function Selected (Choice : Integer) return Integer
   is (case Choice is when 1 .. 4 => Table (Choice), when others => 0)
     with Pre => True;

   --  Guards known not to hold: Count is zero, so nothing below divides by
   --  it or indexes with it.
   procedure Never
     (Total : Integer; Count : Natural; Result : out Integer)
     with Pre => Count = 0
   is
   begin
      Result := (if Count > 0 and then Total / Count > 1 then 1 else 0);
      if Count /= 0 and then Table (Count) = 1 then
         Result := 2;
      end if;
      if Count = 0 or else Table (Count) = 1 then
         Result := 3;
      end if;
      Result := Result + (if Count = 0 then 0 else Total / Count);
      for Step in 1 .. Count loop
         Result := Total / Count;
      end loop;
      case Count is
         when 1 .. 4 => Result := Table (Count);
         when others => null;
      end case;
      Result := Result + (case Count is when 1 .. 4 => Table (Count),
                                        when others => 0);
   end Never;

   Outcome : Integer;
   Seen    : Boolean;
begin
   Seen := Ratio_Above (6, 2);
   Seen := Seen and then Ratio_Or (6, 2);
   Seen := Seen and then Converted (3);
   Outcome := Element_Or_Zero (2) + Chained (3) + Selected (4);
   pragma Assert (Outcome <= 3);
   Never (5, 0, Outcome);
   pragma Assert (Seen or else Outcome <= Integer'Last);
end Verification_Guarded_Operand;

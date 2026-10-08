--  Each procedure makes one claim. The comment beside it says what the
--  program computes: the claims that read true by the symbols are false,
--  but for the three said to hold.
package body Verification_FP116_Declared_Operator with SPARK_Mode is

   procedure Sum is
      Two   : constant Level := 2;
      Three : constant Level := 3;
   begin
      pragma Assert (Integer (Two + Three) = 5);         --  1
   end Sum;

   procedure Distance is
      Two   : constant Level := 2;
      Three : constant Level := 3;
   begin
      pragma Assert (Integer (Two + Three) = 1);         --  holds
   end Distance;

   procedure Product is
      Two   : constant Level := 2;
      Three : constant Level := 3;
   begin
      pragma Assert (Integer (Two * Three) = 6);         --  2
   end Product;

   procedure Remainder is
      Two   : constant Level := 2;
      Three : constant Level := 3;
   begin
      pragma Assert (Integer (Two mod Three) = 2);       --  3
   end Remainder;

   procedure Power is
      Two      : constant Level := 2;
      Exponent : constant Natural := 2;
   begin
      pragma Assert (Integer (Two ** Exponent) = 4);     --  2
   end Power;

   procedure Negation is
      Two : constant Level := 2;
   begin
      pragma Assert (Integer (-Two) /= 2);               --  2
   end Negation;

   procedure Magnitude is
      Two : constant Level := 2;
   begin
      pragma Assert (Integer (abs Two) = 2);             --  0
   end Magnitude;

   procedure Order is
      Two   : constant Level := 2;
      Three : constant Level := 3;
   begin
      pragma Assert (Two < Three);                       --  False
   end Order;

   procedure Order_Reversed is
      Two   : constant Level := 2;
      Three : constant Level := 3;
   begin
      pragma Assert (not (Two < Three));                 --  holds
   end Order_Reversed;

   --  Reached with Left below Right: "<" is then False.
   procedure Order_Branch (Left, Right : Level) is
   begin
      if Left < Right then
         null;
      else
         pragma Assert (Integer (Left) >= Integer (Right));
      end if;
   end Order_Branch;

   procedure Same is
      Two : constant Level := 2;
   begin
      pragma Assert (Two = Two);                         --  False
   end Same;

   procedure Different is
      Two : constant Level := 2;
   begin
      pragma Assert (Two /= Two);                        --  holds
   end Different;

   procedure Not_Different is
      Two : constant Level := 2;
   begin
      pragma Assert (not (Two /= Two));                  --  False
   end Not_Different;

   --  Reached with Left equal to Right: "/=" is always True.
   procedure Different_Branch (Left, Right : Level) is
   begin
      if Left /= Right then
         pragma Assert (Integer (Left) /= Integer (Right));
      end if;
   end Different_Branch;

   --  The operand of a predefined comparison.
   procedure Operand is
      Two   : constant Level := 2;
      Three : constant Level := 3;
   begin
      pragma Assert (Two + Three > Two);                 --  1 > 2
   end Operand;

   procedure Member is
      Two   : constant Level := 2;
      Three : constant Level := 3;
      subtype Fifth is Level range 5 .. 5;
   begin
      pragma Assert (Two + Three in Fifth);              --  1
   end Member;

   --  The bound of an array: Buffer is 1 .. 1.
   procedure Bound is
      Two    : constant Level := 2;
      Three  : constant Level := 3;
      Buffer : constant Table (1 .. Two + Three) := (others => 0);
   begin
      pragma Assert (Buffer'Last = 5);
   end Bound;

   procedure Element is
      Two    : constant Level := 2;
      Three  : constant Level := 3;
      Buffer : constant Table (1 .. Two + Three) := (others => 0);
      Value  : Natural;
   begin
      Value := Buffer (4);                               --  outside 1 .. 1
      pragma Unreferenced (Value);
   end Element;

   --  The bound of a subtype: Narrow is 0 .. 1.
   procedure Narrowed is
      Two   : constant Level := 2;
      Three : constant Level := 3;
      subtype Narrow is Level range 0 .. Two + Three;
      Slot  : Narrow := 0;
   begin
      Slot := 4;                                         --  outside 0 .. 1
      pragma Unreferenced (Slot);
   end Narrowed;

   procedure Inherited is
      Low  : constant Grade := 2;
      High : constant Grade := 3;
   begin
      pragma Assert (Integer (Low + High) = 5);          --  1
   end Inherited;

   procedure Renamed is
      Two    : constant Level := 2;
      Offset : constant Integer := 3;
   begin
      pragma Assert (Integer (Two + Offset) = 5);        --  2
   end Renamed;

   --  The operators of a predefined type can be defined anew as well.
   procedure Whole_Numbers is
      function "+" (Left, Right : Integer) return Integer
      is (Integer'Max (Left, Right));

      Small : constant Integer := 2;
      Large : constant Integer := 3;
   begin
      pragma Assert (Small + Large = 5);                 --  3
   end Whole_Numbers;

   procedure Both is
      function "and" (Left, Right : Boolean) return Boolean is (False);

      Yes : constant Boolean := True;
   begin
      pragma Assert (Yes and Yes);                       --  False
   end Both;

   procedure Either is
      function "or" (Left, Right : Boolean) return Boolean is (True);

      No : constant Boolean := False;
   begin
      pragma Assert (not (No or No));                    --  False
   end Either;

   procedure Opposite is
      function "not" (Right : Boolean) return Boolean is (Right);

      Off : constant Boolean := False;
   begin
      pragma Assert (not Off);                           --  False
   end Opposite;

   procedure Exclusive is
      function "xor" (Left, Right : Boolean) return Boolean is (False);

      On   : constant Boolean := True;
      Idle : constant Boolean := False;
   begin
      pragma Assert (On xor Idle);                       --  False
   end Exclusive;

   --  No division: nothing is wrong with a right operand of zero, and
   --  what the function asks of it is its precondition.
   procedure Quotient is
      Two     : constant Level := 2;
      Nothing : constant Level := 0;
      Share   : Level;
   begin
      Share := Two / Nothing;
      Share := Share / 0;
      pragma Assert (Integer (Share) = 2);               --  holds
   end Quotient;

end Verification_FP116_Declared_Operator;

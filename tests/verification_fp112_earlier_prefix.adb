package body Verification_FP112_Earlier_Prefix with SPARK_Mode is

   procedure Old_Division (Divisor : in out Integer) is
   begin
      Divisor := 1;
   end Old_Division;

   procedure Old_Overflow (Addend : in out Integer) is
   begin
      Addend := 1;
   end Old_Overflow;

   procedure Old_Range (Converted : in out Integer) is
   begin
      Converted := 1;
   end Old_Range;

   procedure Old_Precondition (Passed : in out Integer) is
   begin
      Passed := 1;
   end Old_Precondition;

   procedure Old_Required (Required : in out Integer) is
   begin
      Required := 0;
   end Old_Required;

   procedure Old_Nonzero (Nonzero : in out Integer) is
   begin
      Nonzero := 0;
   end Old_Nonzero;

   procedure Loops (Kept : in out Integer) is
      Late   : Integer;
      Steady : Integer := 5;
      Zeroed : Integer := 0;
      Inner  : Integer := 5;
   begin
      --  Late gets its value inside the loop.
      for Index in 1 .. 3 loop
         Late := 1;
         pragma Assert (Late'Loop_Entry <= Integer'Last);
      end loop;

      --  Steady is five when the loop is entered and one afterwards.
      for Index in 1 .. 3 loop
         Steady := 1;
         pragma Assert (Integer'(10 / Steady)'Loop_Entry <= 10);
      end loop;

      --  Zeroed is zero when the loop is entered.
      for Index in 1 .. 3 loop
         Zeroed := 1;
         pragma Assert (Integer'(10 / Zeroed)'Loop_Entry <= 10);
      end loop;

      --  The inner loop is entered with Inner at zero.
      for Index in 1 .. 3 loop
         Inner := 0;
         for Step in 1 .. 3 loop
            Inner := 2;
            pragma Assert (Integer'(10 / Inner)'Loop_Entry <= 10);
         end loop;
      end loop;

      --  The parameter holds a value when the loop is entered.
      for Index in 1 .. 3 loop
         Kept := 1;
         pragma Assert (Kept'Loop_Entry <= Integer'Last);
      end loop;
   end Loops;

end Verification_FP112_Earlier_Prefix;

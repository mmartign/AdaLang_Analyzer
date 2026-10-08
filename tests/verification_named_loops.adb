package body Verification_Named_Loops with SPARK_Mode is

   procedure Skips_Outer_Body (Leave : Boolean; Result : out Integer) is
      Skipped : Integer := 0;
   begin
      Outer : loop
         loop
            exit Outer when Leave;
            exit;
         end loop;
         Skipped := 5;
         exit Outer;
      end loop Outer;
      Result := 100 / Skipped;
   end Skips_Outer_Body;

   procedure Through_Outer_Body (Leave : Boolean; Result : out Integer) is
      Passed : Integer := 0;
   begin
      Outer : loop
         Inner : loop
            exit Inner when Leave;
            exit Inner;
         end loop Inner;
         Passed := 5;
         exit Outer;
      end loop Outer;
      Result := 100 / Passed;
   end Through_Outer_Body;

   procedure Leaves_Unset (Leave : Boolean; Unset_Result : out Integer) is
   begin
      Outer : for Row in 1 .. 3 loop
         for Column in 1 .. 3 loop
            exit Outer when Leave;
         end loop;
         Unset_Result := Row;
      end loop Outer;
      if not Leave then
         Unset_Result := 0;
      end if;
   end Leaves_Unset;

   procedure Only_Loop (Limit : Integer; Result : out Integer) is
      Steps : Integer := 1;
   begin
      Counting : while Steps < Limit loop
         exit Counting when Steps = 50;
         Steps := Steps + 1;
      end loop Counting;

      Scoped : declare
         Twice : constant Integer := Steps + Steps;
      begin
         Result := 100 / Twice;
      end Scoped;
   end Only_Loop;

   procedure Posted (Leave : Boolean; Differs : out Integer) is
   begin
      Differs := 1;
      Outer : loop
         loop
            exit Outer when Leave;
            exit;
         end loop;
         Differs := 2;
         exit Outer;
      end loop Outer;
   end Posted;

end Verification_Named_Loops;

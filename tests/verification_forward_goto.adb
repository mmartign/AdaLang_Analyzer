package body Verification_Forward_Goto with SPARK_Mode is

   procedure Skips_Assignment (Taken : Boolean; Result : out Integer) is
      Skipped : Integer := 0;
   begin
      if Taken then
         goto Done;
      end if;
      Skipped := 5;

      <<Done>>
      Result := 100 / Skipped;
   end Skips_Assignment;

   procedure Both_Ways
     (Value : Integer; Taken : Boolean; Result : out Integer)
   is
      Either : Integer := Value;
   begin
      if Taken then
         goto Done;
      end if;
      Either := Value + 1;

      <<Done>>
      Result := 100 / Either;
   end Both_Ways;

   procedure Past_Dead_Code (Result : out Integer) is
      Five : Integer := 5;
   begin
      goto Done;
      Five := 0;

      <<Done>>
      Result := 100 / Five;
   end Past_Dead_Code;

   procedure Out_Of_Loop (Result : out Integer) is
      Last : Integer := 0;
   begin
      for Index in 1 .. 10 loop
         if Index = 1 then
            goto Out_Of;
         end if;
         Last := Index;
      end loop;
      Last := 100;

      <<Out_Of>>
      Result := 100 / Last;
   end Out_Of_Loop;

   procedure Skips_Assertion
     (Value : Integer; Taken : Boolean; Result : out Integer) is
   begin
      if Taken then
         goto Done;
      end if;
      pragma Assert (Value > 0);

      <<Done>>
      Result := 100 / Value;
   end Skips_Assertion;

   procedure Leaves_Unset (Taken : Boolean; Unset_Result : out Integer) is
   begin
      if Taken then
         goto Done;
      end if;
      Unset_Result := 1;

      <<Done>>
      null;
   end Leaves_Unset;

   procedure Posted (Taken : Boolean; Same : out Integer) is
   begin
      Same := 2;
      if Taken then
         goto Done;
      end if;
      Same := 1;
      Same := Same + 1;

      <<Done>>
      null;
   end Posted;

   procedure Posted_On_One_Way (Taken : Boolean; Differs : out Integer) is
   begin
      Differs := 1;
      if Taken then
         goto Done;
      end if;
      Differs := 2;

      <<Done>>
      null;
   end Posted_On_One_Way;

   procedure Continues (Count : in out Integer; Taken : Boolean) is
      Kept : Integer := 1;
   begin
      while Count > 0 loop
         pragma Loop_Invariant (Kept >= 0);
         Count := Count - 1;
         if Taken then
            goto Continue;
         end if;
         Kept := -1;

         <<Continue>>
         null;
      end loop;
   end Continues;

   procedure From_Handler (Value : Integer; Result : out Integer) is
      Guarded : Integer;
   begin
      begin
         if Value = 0 then
            raise Program_Error;
         end if;
         Guarded := Value;
      exception
         when Program_Error =>
            Guarded := 0;
            goto After;
      end;
      Guarded := 1;

      <<After>>
      Result := 100 / Guarded;
   end From_Handler;

end Verification_Forward_Goto;

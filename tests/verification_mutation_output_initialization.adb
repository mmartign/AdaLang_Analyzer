procedure Verification_Mutation_Output_Initialization
  with SPARK_Mode
is
   type Triple is array (1 .. 3) of Integer;

   --  One branch leaves the parameter unassigned.
   procedure Set_Sometimes (Flag : Boolean; Partial : out Integer) is
   begin
      if Flag then
         Partial := 1;
      end if;
   end Set_Sometimes;

   --  No path assigns the parameter.
   procedure Set_Never (Missing : out Integer) is
   begin
      null;
   end Set_Never;

   --  An early return skips the assignment.
   procedure Set_After_Return (Flag : Boolean; Skipped : out Integer) is
   begin
      if Flag then
         return;
      end if;
      Skipped := 1;
   end Set_After_Return;

   --  Only one element is assigned; the model does not follow elements,
   --  so this must not be called initialized.
   procedure Set_One_Element (Element_Only : out Triple) is
   begin
      Element_Only (1) := 0;
   end Set_One_Element;

   --  The assignment is in a loop that may run zero times.
   procedure Set_In_Loop (Count : Natural; Looped : out Integer) is
   begin
      for Index in 1 .. Count loop
         Looped := Index;
      end loop;
   end Set_In_Loop;

   Value : Integer := 0;
   Items : Triple := (others => 0);
begin
   Set_Sometimes (False, Value);
   Set_Never (Value);
   Set_After_Return (True, Value);
   Set_One_Element (Items);
   Set_In_Loop (0, Value);
end Verification_Mutation_Output_Initialization;

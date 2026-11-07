package body Verification_Mutation_Outside_Objects
  with SPARK_Mode
is
   function Read_Bare return Integer is (Bare);
   function Read_Expanded return Integer is (Expanded);
   function "+" (L, R : Number) return Number is
     (if Operator > 0 then L else R);
   function Read_In_Contract return Integer is (In_Contract);
   function Read_In_Declaration return Integer is (In_Declaration);
   function Read_In_Assertion return Integer is (In_Assertion);

   procedure Read_Before_Call (R : out Integer) is
   begin
      R := Before_Call;
   end Read_Before_Call;

   procedure Set_Before_Call is
   begin
      Before_Call := 1;
   end Set_Before_Call;

   procedure Read_One_Path (R : out Integer) is
   begin
      R := One_Path;
   end Read_One_Path;

   procedure Set_One_Path is
   begin
      One_Path := 1;
   end Set_One_Path;

   procedure Keep_In_Out is
   begin
      if In_Out_Early > 10 then
         In_Out_Early := 10;
      end if;
   end Keep_In_Out;

   procedure Call_Too_Early (R : out Integer) is
   begin
      Read_Before_Call (R);
      Set_Before_Call;
   end Call_Too_Early;

   procedure Call_After_Branch (C : Boolean; R : out Integer) is
   begin
      if C then
         Set_One_Path;
      end if;
      Read_One_Path (R);
   end Call_After_Branch;

   procedure Bare_Too_Early (R : out Integer) is
   begin
      R := Read_Bare;
      Bare := 1;
   end Bare_Too_Early;

   procedure Expanded_Too_Early (R : out Integer) is
   begin
      R := Verification_Mutation_Outside_Objects.Read_Expanded;
      Expanded := 1;
   end Expanded_Too_Early;

   procedure Operator_Too_Early (X : Number; R : out Number) is
   begin
      R := X + X;
      Operator := 1;
   end Operator_Too_Early;

   procedure Contract_Too_Early is
   begin
      In_Contract := 1;
   end Contract_Too_Early;

   procedure In_Out_Too_Early is
   begin
      Keep_In_Out;
      In_Out_Early := 1;
   end In_Out_Too_Early;

   procedure Declaration_Too_Early (R : out Integer) is
      Y : constant Integer := Read_In_Declaration;
   begin
      R := Y;
      In_Declaration := 1;
   end Declaration_Too_Early;

   procedure Assertion_Too_Early is
   begin
      pragma Assert (Read_In_Assertion = Read_In_Assertion);
      In_Assertion := 1;
   end Assertion_Too_Early;

   procedure Nested_Early (R : out Integer) is
      Unset_Local : Integer;

      procedure Inner (Q : out Integer)
        with Global => (Input => Unset_Local)
      is
      begin
         Q := Unset_Local;
      end Inner;
   begin
      Inner (R);
      Unset_Local := 3;
   end Nested_Early;

   generic
      with procedure Give (V : out Integer);
   procedure Take_Given (R : out Integer);

   procedure Take_Given (R : out Integer) is
   begin
      Give (R);
   end Take_Given;

   --  No call names Reader, so none says what it reads.
   procedure Through_Instance (R : out Integer) is
      Unset_Actual : Integer;

      procedure Reader (V : out Integer)
        with Global => (Input => Unset_Actual)
      is
      begin
         V := Unset_Actual;
      end Reader;

      procedure Take is new Take_Given (Reader);
   begin
      Take (R);
      Unset_Actual := 3;
   end Through_Instance;

   procedure Nested_No_Contract (R : out Integer) is
      Unset_Read : Integer;

      procedure Inner (Q : out Integer) is
      begin
         Q := Unset_Read;
      end Inner;
   begin
      Inner (R);
      Unset_Read := 3;
   end Nested_No_Contract;

   procedure Nested_Branch (C : Boolean; R : out Integer) is
      Branch_Local : Integer;

      procedure Inner (Q : out Integer)
        with Global => (Input => Branch_Local)
      is
      begin
         Q := Branch_Local;
      end Inner;
   begin
      if C then
         Branch_Local := 3;
      end if;
      Inner (R);
   end Nested_Branch;

   procedure Missing_Component (Short : out Whole) is
   begin
      Short.A := 1;
   end Missing_Component;

   procedure Component_One_Path (C : Boolean; Branch : out Whole) is
   begin
      Branch.A := 1;
      if C then
         Branch.B := (others => 0);
      end if;
   end Component_One_Path;

   procedure Missing_Nested (Deep : out Nest) is
   begin
      Deep.I.P := 1;
      Deep.Z := 3;
   end Missing_Nested;

   procedure Same_Name_Elsewhere (Doubled : out Twice) is
   begin
      Doubled.I.P := 1;
      Doubled.I.Q := 1;
      Doubled.J.Q := 1;
   end Same_Name_Elsewhere;

   procedure Default_Not_Taken (Default : out Defaulted) is
   begin
      Default.B := 1;
   end Default_Not_Taken;

   procedure Variant_Branch (Choice : out Variant) is
   begin
      Choice.L := 1;
   end Variant_Branch;

   procedure Missing_Parent (Child_Part : out Extended) is
   begin
      Child_Part.B := 2;
   end Missing_Parent;

   function Other_Component return Integer is
      Partly : Whole;
   begin
      Partly.A := 1;
      return Partly.B (1);
   end Other_Component;

   function Other_Object return Integer is
      Given, Never : Pair;
   begin
      Given.P := 1;
      return Never.P + Given.P * 0;
   end Other_Object;

   procedure Short_Loop (Short_Range : out Cells) is
   begin
      for I in 1 .. 3 loop
         Short_Range (I) := 0;
      end loop;
   end Short_Loop;

   procedure Subtype_Loop (Sub_Range : out Cells) is
   begin
      for I in Few loop
         Sub_Range (I) := 0;
      end loop;
   end Subtype_Loop;

   procedure Conditional_Loop (C : Boolean; Guarded : out Cells) is
   begin
      for I in Guarded'Range loop
         if C then
            Guarded (I) := 0;
         end if;
      end loop;
   end Conditional_Loop;

   procedure Exit_Loop (Left_Early : out Cells) is
   begin
      for I in Left_Early'Range loop
         Left_Early (I) := 0;
         exit when I = 2;
      end loop;
   end Exit_Loop;

   procedure Other_Index_Loop (Other_Index : out Cells) is
   begin
      for I in Other_Index'Range loop
         Other_Index (I + 0) := 0;
      end loop;
   end Other_Index_Loop;

   procedure Maybe_Relaxed (C : Boolean) is
   begin
      if C then
         Relaxed_Global := 1;
      end if;
   end Maybe_Relaxed;

   procedure Maybe_Second (C : Boolean) is
   begin
      if C then
         Second_Relaxed := 1;
      end if;
   end Maybe_Second;

   procedure Maybe_Soft (C : Boolean) is
   begin
      if C then
         Soft_Global := 1;
      end if;
   end Maybe_Soft;

   procedure Maybe_Cells (C : Boolean; X : out Cells) is
   begin
      if C then
         X := (others => 1);
      end if;
   end Maybe_Cells;

   procedure Maybe_Pair (C : Boolean; X : out Soft_Pair) is
   begin
      X.B := 1;
      if C then
         X.A := 1;
      end if;
   end Maybe_Pair;

   procedure After_Relaxed_Output (C : Boolean; R : out Integer) is
   begin
      Maybe_Relaxed (C);
      R := Relaxed_Global;
   end After_Relaxed_Output;

   procedure After_Soft_Output (C : Boolean; R : out Integer) is
   begin
      Maybe_Soft (C);
      R := Integer (Soft_Global);
   end After_Soft_Output;

   procedure Set_Then_Output (C : Boolean; R : out Integer) is
   begin
      Second_Relaxed := 1;
      Maybe_Second (C);
      R := Second_Relaxed;
   end Set_Then_Output;

   procedure After_Relaxed_Out (C : Boolean; R : out Integer) is
      Soft_Cells : Cells;
   begin
      Maybe_Cells (C, Soft_Cells);
      R := Soft_Cells (1);
   end After_Relaxed_Out;

   procedure After_Component_Out (C : Boolean; R : out Integer) is
      Soft_Holder : Soft_Pair;
   begin
      Maybe_Pair (C, Soft_Holder);
      R := Integer (Soft_Holder.A);
   end After_Component_Out;

   procedure Parts_Then_Out (C : Boolean; R : out Integer) is
      Soft_Parts : Soft_Pair;
   begin
      Soft_Parts.A := 2;
      Soft_Parts.B := 2;
      Maybe_Pair (C, Soft_Parts);
      R := Integer (Soft_Parts.A);
   end Parts_Then_Out;

   function Element_By_Element return Integer is
      Each : Cells;
   begin
      Each (1) := 1;
      Each (2) := 1;
      Each (3) := 1;
      Each (4) := 1;
      return Each (1);
   end Element_By_Element;

   procedure Maybe_Some (C : Boolean; X : out Open_Cells) is
   begin
      if C then
         X := (others => 1);
      end if;
   end Maybe_Some;

   procedure Maybe_Two (C : Boolean; X, Y : out Cells; Z : out Integer) is
   begin
      Z := 1;
      if C then
         X := (others => 1);
         Y := (others => 1);
      end if;
   end Maybe_Two;

   procedure After_Relaxed_Slice (C : Boolean; R : out Integer) is
      Soft_Slice : Open_Cells (1 .. 4) := (others => 0)
        with Relaxed_Initialization;
      From       : Integer := 2;
   begin
      Maybe_Some (C, Soft_Slice (From .. From + 1));
      pragma Assert (Soft_Slice'Initialized);
      R := Soft_Slice (2);
   end After_Relaxed_Slice;

   procedure After_Component_Slice (C : Boolean; R : out Integer) is
      Soft_Whole : Soft_Box := (D => (others => 0));
      From       : Integer := 2;
   begin
      Maybe_Some (C, Soft_Whole.D (From .. From + 1));
      pragma Assert (Soft_Whole'Initialized);
      R := Soft_Whole.D (2);
   end After_Component_Slice;

   procedure After_Second_Listed (C : Boolean; R : out Integer) is
      First_Listed, Second_Listed : Cells;
      Third                       : Integer;
   begin
      Maybe_Two (C, First_Listed, Second_Listed, Third);
      R := Second_Listed (1);
   end After_Second_Listed;
end Verification_Mutation_Outside_Objects;

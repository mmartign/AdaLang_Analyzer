package body Verification_Outside_Objects
  with SPARK_Mode
is
   package body Keeper with Refined_State => (Kept => Cell) is
      Cell : Integer;

      procedure Store with Refined_Global => (Output => Cell) is
      begin
         Cell := 1;
      end Store;

      procedure Fetch (R : out Integer) with Refined_Global => (Input => Cell)
      is
      begin
         R := Cell;
      end Fetch;
   end Keeper;

   procedure Give_One (V : out Integer) is
   begin
      V := 1;
   end Give_One;

   procedure Give_Cells (V : out Cells) is
   begin
      V := (others => 0);
   end Give_Cells;

   procedure Read_Shared (R : out Integer) is
   begin
      R := Shared;
   end Read_Shared;

   procedure Set_Shared is
   begin
      Shared := 1;
   end Set_Shared;

   procedure Keep_Shared is
   begin
      if Shared > 10 then
         Shared := 10;
      end if;
   end Keep_Shared;

   function Shared_Value return Integer is (Shared);

   procedure Set_Then_Read (R : out Integer) is
   begin
      Set_Shared;
      Read_Shared (R);
   end Set_Then_Read;

   procedure Set_Then_Keep (R : out Integer) is
   begin
      Set_Shared;
      Keep_Shared;
      Read_Shared (R);
   end Set_Then_Keep;

   procedure Set_Then_Bare (R : out Integer) is
   begin
      Set_Shared;
      R := Shared_Value;
   end Set_Then_Bare;

   procedure Pass_On (R : out Integer) is
   begin
      Read_Shared (R);
   end Pass_On;

   Seeded : Integer := 0;

   procedure Generated (R : out Integer) is
   begin
      R := Seeded;
   end Generated;

   procedure Store_Kept is
   begin
      Keeper.Store;
   end Store_Kept;

   procedure Nested_Input (R : out Integer) is
      Local : Integer;

      procedure Inner (Q : out Integer) with Global => (Input => Local) is
      begin
         Q := Local;
      end Inner;
   begin
      Local := 3;
      Inner (R);
   end Nested_Input;

   procedure Nested_Output (R : out Integer) is
      Local : Integer;

      procedure Inner with Global => (Output => Local) is
      begin
         Local := 4;
      end Inner;
   begin
      Inner;
      R := Local;
   end Nested_Output;

   generic
      with procedure Give (V : out Integer);
   procedure Take_Given (R : out Integer);

   procedure Take_Given (R : out Integer) is
      Taken : Integer;
   begin
      Give (Taken);
      R := Taken;
   end Take_Given;

   procedure Take_One is new Take_Given (Give_One);

   procedure Through_Formal (R : out Integer) is
   begin
      Take_One (R);
   end Through_Formal;

   procedure By_Components (By_Assignment : out Whole) is
   begin
      By_Assignment.A := 1;
      By_Assignment.B := (others => 0);
   end By_Components;

   procedure By_Calls (By_Actuals : out Whole) is
   begin
      Give_One (By_Actuals.A);
      Give_Cells (By_Actuals.B);
   end By_Calls;

   procedure Nested_Components (Deep : out Nest) is
   begin
      Deep.I.P := 1;
      Deep.I.Q := 2;
      Deep.Z := 3;
   end Nested_Components;

   procedure Extension (Extended_Value : out Extended) is
   begin
      Extended_Value.A := 1;
      Extended_Value.B := 2;
   end Extension;

   function Part_Read return Integer is
      Partly : Whole;
   begin
      Partly.A := 1;
      return Partly.A;
   end Part_Read;

   procedure Range_Loop (Filled : out Cells) is
   begin
      for I in Filled'Range loop
         Filled (I) := 0;
      end loop;
   end Range_Loop;

   procedure Backward_Loop (Backward : out Cells) is
   begin
      for I in reverse Backward'Range loop
         Backward (I) := 0;
      end loop;
   end Backward_Loop;

   procedure Index_Loop (Indexed : out Few_Cells) is
   begin
      for I in Few loop
         Indexed (I) := 0;
      end loop;
   end Index_Loop;

   procedure Component_Loop (Field : out Whole) is
   begin
      Field.A := 0;
      for I in Field.B'Range loop
         Field.B (I) := 0;
      end loop;
   end Component_Loop;

   function Local_Loop return Integer is
      Local : Cells;
   begin
      for I in Local'Range loop
         Local (I) := I;
      end loop;
      return Local (1);
   end Local_Loop;

   procedure Fresh (Unset : out Sized) is
   begin
      Unset := (N => 1, L => 0);
   end Fresh;

   procedure Listed (X : out Open_Cells; N : out Integer) is
   begin
      X := (others => 1);
      N := 1;
   end Listed;

   function Unlisted_Read return Integer is
      Held     : Open_Cells (1 .. 4) with Relaxed_Initialization;
      Unlisted : Integer;
   begin
      Listed (Held, Unlisted);
      return Unlisted;
   end Unlisted_Read;

   function Index_Read return Integer is
      Held        : Open_Cells (1 .. 4) with Relaxed_Initialization;
      Slice_Index : Integer := 2;
      Ignored     : Integer;
   begin
      Listed (Held (Slice_Index .. Slice_Index + 1), Ignored);
      return Slice_Index;
   end Index_Read;
end Verification_Outside_Objects;

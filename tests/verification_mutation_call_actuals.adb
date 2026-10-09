package body Verification_Mutation_Call_Actuals is

   package body Shapes is

      procedure Fill (Shape : Root; X : out Integer) is
      begin
         X := 1;
      end Fill;

      --  It leaves X as it found it: with no value.
      overriding procedure Fill (Shape : Hollow; X : out Integer) is
      begin
         null;
      end Fill;

      --  The call may run the Fill of Hollow.
      procedure Through_Class (Shape : Root'Class; R : out Integer) is
         Dispatched : Integer;
      begin
         Fill (Shape, Dispatched);
         R := Dispatched;
      end Through_Class;

   end Shapes;

   package body Plain is

      procedure Give (X : out Small) is
      begin
         X := 1;
      end Give;

      procedure Never (X : out Integer) is
      begin
         null;
      end Never;

      function Take (X : out Integer) return Boolean is
      begin
         return False;
      end Take;

      procedure Run (Action : not null access procedure) is
      begin
         Action.all;
      end Run;

      --  Give is not SPARK code: Given is initialized, as its body shows,
      --  and nothing more is taken of it.
      procedure After_Body (T : Table; R : out Integer) is
         Given : Integer;
      begin
         Give (Given);
         R := T (Given);
      end After_Body;

      --  An out parameter of a scalar type comes back as the callee left
      --  it: Stale has no value after the call.
      procedure After_Never (R : out Integer) is
         Stale : Integer := 5;
      begin
         Never (Stale);
         pragma Assert (Stale = 5);
         R := Stale;
      end After_Never;

      procedure After_Function (R : out Integer) is
         Taken : Integer := 5;
         Done  : Boolean;
      begin
         Done := Take (Taken);
         R := (if Done then 0 else Taken);
      end After_Function;

      --  Not SPARK code: a component is not taken to be within its subtype.
      procedure Component (C : Counter; T : Table; R : out Integer) is
      begin
         R := T (C.Count);
      end Component;

      --  External may write whatever is declared outside this subprogram.
      procedure Outside_Object (R : out Integer) is
      begin
         Shared := 7;
         External;
         R := 100 / Shared;
      end Outside_Object;

      --  Run is declared outside this subprogram and is handed code that
      --  is declared in it: Reached is 0 when Run returns.
      procedure With_Local_Code (R : out Integer) is
         Reached : Integer := 7;

         procedure Clear is
         begin
            Reached := 0;
         end Clear;
      begin
         Run (Clear'Access);
         R := 100 / Reached;
      end With_Local_Code;

      --  Fill is declared outside this subprogram, which declares no code,
      --  and is given the address of Counted: it is no longer 0.
      procedure Through_Address (R : out Integer) is
         Counted : Integer := 0;
      begin
         Fill (Counted'Address);
         pragma Assert (Counted = 0);
         R := Counted;
      end Through_Address;

      --  Far goes past the last index of T, and stays within its subtype.
      procedure Widened_Past (N : Natural; T : Table; R : out Integer) is
         Far : Integer range 0 .. 1000 := 0;
      begin
         for Round in 1 .. N loop
            if Far < 200 then
               Far := Far + 1;
            end if;
         end loop;
         R := T (Far);
      end Widened_Past;

   end Plain;

   package body Loose is

      procedure First (X : out Small) is
      begin
         X := Limit;
      end First;

      procedure After_First (T : Table; R : out Integer) is
         Loosened : Integer;
      begin
         First (Loosened);
         R := T (Loosened);
      end After_First;

   end Loose;

   package Fives is new Loose (Limit => 5);

   package body Kept with SPARK_Mode => On is

      procedure Bump (X : in out Small) is
      begin
         if X < 100 then
            X := X + 1;
         end if;
      end Bump;

      --  Initialized still, and no longer 5.
      procedure After_In_Out (R : out Integer) is
         Carried : Integer := 5;
      begin
         Bump (Carried);
         pragma Assert (Carried = 5);
         R := Carried;
      end After_In_Out;

      --  What was not initialized before the call is not known to be
      --  after it, and nothing is said of its value.
      procedure Unset_In_Out (T : Table; R : out Integer) is
         Unset : Integer;
      begin
         Bump (Unset);
         R := T (Unset);
      end Unset_In_Out;

      --  Within its subtype is not within half of it.
      procedure Component_Half (C : Counter; R : out Integer) is
      begin
         pragma Assert (C.Count <= 50);
         R := C.Count;
      end Component_Half;

   end Kept;

   procedure Use_Instance (T : Table; R : out Integer) is
   begin
      Fives.After_First (T, R);
   end Use_Instance;

end Verification_Mutation_Call_Actuals;

package body Verification_Call_Actuals is

   package body Plain is

      procedure Give (X : out Small) is
      begin
         X := 1;
      end Give;

      procedure Bump (X : in out Small) is
      begin
         if X < 100 then
            X := X + 1;
         end if;
      end Bump;

      --  The statements of Give write its parameter whatever the path.
      procedure After_Body (R : out Integer) is
         Given : Integer;
      begin
         Give (Given);
         R := Given;
      end After_Body;

      procedure After_In_Out (R : out Integer) is
         Bumped : Integer := 5;
      begin
         Bump (Bumped);
         R := Bumped;
      end After_In_Out;

      --  Turn grows by one each round: the loop is not followed round by
      --  round until it stops growing, and Turn is taken up to the last
      --  value of its subtype, which the body of the loop then keeps to.
      procedure Widened (N : Natural; T : Table; R : out Integer) is
         Turn : Small := 0;
      begin
         for Round in 1 .. N loop
            if Turn < 100 then
               Turn := Turn + 1;
            end if;
         end loop;
         R := T (Turn);
      end Widened;

      --  Ask is handed an access value to Told: nothing says Told is still
      --  without a value after the call.
      procedure Through_Access (R : out Integer) is
         Told : aliased Boolean;
      begin
         Ask (Told'Access);
         R := (if Told then 1 else 0);
      end Through_Access;

   end Plain;

   package body Bounded is

      procedure First (X : out Small) is
      begin
         X := Limit;
      end First;

      procedure After_First (T : Table; R : out Integer) is
         Started : Integer;
      begin
         First (Started);
         R := T (Started);
      end After_First;

   end Bounded;

   package body Kept with SPARK_Mode => On is

      --  Written on every path, which the loop keeps the statements of the
      --  body from showing.
      procedure Give (X : out Small) is
      begin
         loop
            X := 1;
            exit;
         end loop;
      end Give;

      procedure Bump (X : in out Small) is
      begin
         if X < 100 then
            X := X + 1;
         end if;
      end Bump;

      procedure Reset (C : in out Counter) is
      begin
         C.Step := 1;
      end Reset;

      package Tens is new Bounded (Limit => 10);

      procedure After_Out (T : Table; R : out Integer) is
         Fresh : Integer;
      begin
         Give (Fresh);
         R := T (Fresh);
      end After_Out;

      procedure After_In_Out (T : Table; R : out Integer) is
         Carried : Integer := 5;
      begin
         Bump (Carried);
         R := T (Carried);
      end After_In_Out;

      --  External cannot name Apart, and is not given it.
      procedure After_External (R : out Integer) is
         Apart : Integer := 7;
      begin
         External;
         R := 100 / Apart;
      end After_External;

      procedure Component (C : Counter; T : Table; R : out Integer) is
      begin
         R := T (C.Count);
      end Component;

      procedure Component_After_Call
        (C : in out Counter; T : Table; R : out Integer) is
      begin
         Reset (C);
         R := T (C.Step);
      end Component_After_Call;

      procedure Through_Instance (T : Table; R : out Integer) is
      begin
         Tens.After_First (T, R);
      end Through_Instance;

   end Kept;

end Verification_Call_Actuals;

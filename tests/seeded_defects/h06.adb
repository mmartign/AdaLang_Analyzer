package body H06 is
   procedure Unrelated is
   begin
      null;
   end Unrelated;

   procedure Touch_Registry is
   begin
      Registry.all := 0;
   end Touch_Registry;

   procedure Mutate (R : in out Rec) is
   begin
      R := (K => C);
   end Mutate;

   --  modular wrap on the abstract path
   procedure M01 (N : Byte; Sink : out Byte) is
      M : Byte := 255;
      T : Byte := 128;
   begin
      Sink := 10 / (M + 1);              --  BAD
      Sink := 10 / (T * 2);              --  BAD
      Sink := 10 / (T + T);              --  BAD
      M := 0;
      Sink := 10 / (M - 1 - 255);        --  BAD
      Sink := 10 / (N + 1);              --  BAD
      Sink := 10 / (-T + 128);           --  BAD
      Sink := 10 / (not M - 255);        --  BAD
      Sink := 10 / (M + 256);            --  ERR
   end M01;

   --  narrowing on a volatile / atomic object
   procedure M02 (N : Integer; Sink : out Integer) is
   begin
      Sink := N;
      if V > 0 then
         Sink := 10 / V;                 --  BAD
      end if;
      if At_Var in 1 .. 5 then
         Sink := 10 / At_Var;            --  BAD
      end if;
      pragma Assert (V = V);             --  BAD:assertion
   end M02;

   --  aliased local whose access escaped, then an unrelated call
   procedure M03 (N : Integer; Sink : out Integer) is
      X : aliased Integer := 5;
   begin
      Registry := X'Unchecked_Access;
      X := 5;
      Touch_Registry;
      Sink := 10 / X + N;                --  BAD
   end M03;

   procedure M04 (N : Integer; Sink : out Integer) is
      X : aliased Integer := 5;
      P : constant Int_Access := X'Unchecked_Access;
   begin
      Registry := P;
      X := 5;
      Unrelated;
      Touch_Registry;
      Sink := 10 / X + N;                --  BAD
   end M04;

   --  read through a renaming after the renamed object changed
   procedure M05 (N : Integer; Sink : out Integer) is
      Y : Integer := 5;
      Z : Integer renames Y;
   begin
      Z := 5;
      Y := N - N;
      Sink := 10 / Z;                    --  BAD
   end M05;

   --  renaming of a component / element
   procedure M06 (N : Integer; Sink : out Integer) is
      type Pair is record
         L, R : Integer;
      end record;
      P : Pair := (5, 5);
      Z : Integer renames P.L;
   begin
      P.L := 5;
      Z := N - N;
      Sink := 10 / P.L;                  --  BAD
   end M06;

   procedure M07 (N : Integer; Sink : out Integer) is
      A : array (1 .. 3) of Integer := (others => 5);
      Z : Integer renames A (2);
   begin
      A (2) := 5;
      Z := N - N;
      Sink := 10 / A (2);                --  BAD
   end M07;

   --  discriminant checks on mutable records
   procedure M08 (N : Integer; Sink : out Integer) is
      R : Rec := (K => A, X => 1);
   begin
      if N > 0 then
         R := (K => B, Y => 2);
      end if;
      Sink := R.X;                       --  BAD:discriminant-check
   end M08;

   procedure M09 (N : Integer; Sink : out Integer) is
      R : Rec := (K => A, X => 1);
   begin
      Mutate (R);
      Sink := R.X + N;                   --  BAD:discriminant-check
   end M09;

   procedure M10 (N : Integer; Sink : out Integer) is
      R : Rec_A := (K => A, X => 1);
   begin
      Sink := R.X + N;                   --  OK:discriminant-check
      Sink := R.Y;                       --  BAD:discriminant-check
   end M10;

   procedure M11 (N : Integer; Sink : out Integer) is
      R : Rec (B);
   begin
      R.Y := N;
      Sink := R.Y;                       --  OK:discriminant-check
      Sink := R.X;                       --  BAD:discriminant-check
   end M11;

   --  initialization
   procedure M12 (N : Integer; Sink : out Integer) is
      X : Integer;
   begin
      if N > 0 then
         X := 1;
      end if;
      Sink := X;                         --  BAD:initialization-check
   end M12;

   procedure M13 (N : Integer; Sink : out Integer) is
      X : Integer;
   begin
      for I in 1 .. N loop
         X := I;
      end loop;
      Sink := X;                         --  BAD:initialization-check
   end M13;

   procedure M14 (N : Integer; Sink : out Integer) is
      X : Integer;
   begin
      begin
         Sink := 10 / N;
         X := 1;
      exception
         when Constraint_Error =>
            Sink := 0;
      end;
      Sink := X;                         --  BAD:initialization-check
   end M14;

   procedure M15 (N : Integer; Sink : out Integer) is
      X : Integer;
      Y : Integer;
   begin
      case N is
         when 1 => X := 1; Y := 1;
         when 2 => X := 2;
         when others => X := 3; Y := 3;
      end case;
      Sink := X;                         --  OK:initialization-check
      Sink := Y;                         --  BAD:initialization-check
   end M15;

   procedure M16 (N : Integer; Sink : out Integer) is
      X : Integer;
      procedure Maybe (V : out Integer) is
      begin
         if N > 0 then
            V := 1;
         end if;
      end Maybe;
   begin
      Maybe (X);
      Sink := X;                         --  BAD:initialization-check
   end M16;

   procedure M17 (N : Integer; Sink : out Integer) is
      X : Integer;
      I : Integer := 0;
   begin
      while I < N loop
         I := I + 1;
         if I = 3 then
            X := I;
            exit;
         end if;
      end loop;
      Sink := X;                         --  BAD:initialization-check
   end M17;

   --  out parameter left unset on a path
   procedure M18 (N : Integer; Sink : out Integer) is
   begin
      if N > 0 then
         Sink := 1;
      end if;
   end M18;

   --  reachability: code that must not be reported unreachable
   procedure M19 (N : Integer; Sink : out Integer) is
      X : Integer := N;
   begin
      Sink := 0;
      if X > X - 1 then
         null;
      else
         Sink := 10 / (X - X);           --  OK
      end if;
      if N * 0 = 0 then
         Sink := 10 / (N - 7);           --  BAD
      end if;
      if N + 1 > N then
         Sink := 1;
      else
         Sink := 10 / (N - Integer'Last);   --  OK
      end if;
   end M19;

   procedure M20 (N : Integer; Sink : out Integer) is
      F : constant Boolean := N > 0;
      T : Boolean := True;
   begin
      Sink := 0;
      if F and not F then
         Sink := 10 / (N - N);           --  OK
      end if;
      if F xor T then
         Sink := 10 / (N + 1);           --  BAD
      end if;
      T := F;
      if not T then
         Sink := 10 / N;                 --  BAD
      end if;
      if T = F then
         Sink := 10 / (N - 3);           --  BAD
      end if;
   end M20;

   procedure M21 (N : Integer; Sink : out Integer) is
      X : Integer := 0;
   begin
      Sink := 0;
      loop
         X := X + 1;
         if X > 3 then
            exit;
         end if;
      end loop;
      Sink := 10 / (X - 4) + N;          --  BAD
   end M21;

   procedure M22 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      Sink := 0;
      begin
         if N > 3 then
            raise Program_Error;
         end if;
         X := N;
      exception
         when Program_Error =>
            Sink := 10 / (N - 4);        --  BAD
            X := 0;
      end;
      Sink := 10 / X;                    --  BAD
   end M22;
end H06;

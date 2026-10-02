package body H04 with SPARK_Mode is
   procedure Needs_Pos (X : Integer) is null;
   procedure Needs_Both (X : Integer; Y : Integer) is null;
   procedure Needs_Default (X : Integer; Y : Integer := 0) is null;
   procedure Needs_G (X : Integer) is null;

   procedure Bump (X : in out Integer) is
   begin
      X := X + 1;
   end Bump;

   procedure Weak (X : in out Integer) is
   begin
      X := 0;
   end Weak;

   function Twice (X : Integer) return Integer is (2 * X);
   function Opaque (X : Integer) return Integer is (X - X);

   procedure C01 (N : Integer) is
   begin
      Needs_Pos (N);                      --  BAD:precondition
      Needs_Pos (N - N);                  --  BAD:precondition
      Needs_Both (Y => 1, X => 2);        --  BAD:precondition
      Needs_Both (1, 2);                  --  OK:precondition
      Needs_Default (5);                  --  BAD:precondition
      Needs_Default (5, 1);               --  OK:precondition
   end C01;

   procedure C02 (N : Integer) is
   begin
      G := 5 + N - N;
      Needs_G (4);                        --  OK:precondition
      Needs_G (5);                        --  BAD:precondition
      G := 0;
      Needs_G (-1);                       --  OK:precondition
      Needs_G (0);                        --  BAD:precondition
   end C02;

   procedure C03 (N : Integer) is
      X : Integer := N;
   begin
      if X > 0 then
         X := X - 1;
         Needs_Pos (X);                   --  BAD:precondition
      end if;
   end C03;

   procedure C04 (N : Integer) is
      X : Integer := 1;
   begin
      Weak (X);
      Needs_Pos (X);                      --  BAD:precondition
      X := 99 + N - N;
      Bump (X);
      Needs_Pos (X - 99);                 --  OK:precondition
      Needs_Pos (X - 100);                --  BAD:precondition
   end C04;

   procedure C05 (N : Integer; Sink : out Integer) is
      X : Integer := 1;
   begin
      Weak (X);
      Sink := 10 / X + N;                 --  BAD
   end C05;

   procedure C06 (N : Integer; Sink : out Integer) is
      X : Integer := 5 + N - N;
   begin
      Bump (X);
      Bump (X);
      Sink := 10 / (X - 7);               --  BAD
   end C06;

   procedure C07 (N : Integer; Sink : out Integer) is
   begin
      if N in -100 .. 100 then
         Sink := 10 / (Twice (N) - 4);    --  BAD
      else
         Sink := 10 / (Opaque (N) + 0);   --  BAD
      end if;
   end C07;

   procedure C08 (X : in out Integer) is
   begin
      X := X - 5;
      X := 10 / X;                        --  BAD
   end C08;

   procedure C09 (X : in out Integer) is
   begin
      X := X - 1;
      X := X + 1;
   end C09;                               

   procedure C10 (X : in out Integer) is
   begin
      X := X + 1;
      X := X + 1;
      X := X - 1;
   end C10;

   procedure C11 (N : Integer; X : out Integer) is
   begin
      X := 0;
      if N > 0 then
         return;
      end if;
      X := 5;
   end C11;

   procedure C12 (N : Integer; X : out Integer) is
   begin
      X := 5;
      for I in 1 .. N loop
         X := X - 1;
         exit when I = 2;
      end loop;
   end C12;

   function C13 (N : Integer) return Integer is
   begin
      if N > 0 then
         return N;
      elsif N < -5 then
         return 1;
      end if;
      return N + 5;
   end C13;

   function C14 (N : Integer) return Integer is
      R : Integer := N;
   begin
      if N > 5 then
         R := R + 1;
      end if;
      return R;
   end C14;

   procedure C15 (N : Integer; X : in out Integer) is
   begin
      for I in 1 .. N loop
         X := X * 2;
         exit when X > 1000;
      end loop;
   end C15;

   procedure C16 (N : Integer; Sink : out Integer) is
      X : Integer := 0;
   begin
      for I in 1 .. N loop
         pragma Loop_Invariant (X = I - 1);
         X := X + 1;
      end loop;
      pragma Assert (X >= 1);             --  BAD:assertion
      Sink := 10 / X;
   end C16;

   procedure C17 (N : Integer; Sink : out Integer) is
      X : Integer := 0;
      I : Integer := 0;
   begin
      while I < N loop
         pragma Loop_Invariant (X = 2 * I);            --  OK:loop-invariant-preservation
         pragma Loop_Invariant (X <= 10);              --  BAD:loop-invariant-preservation
         X := X + 2;
         I := I + 1;
      end loop;
      Sink := X;
   end C17;

   procedure C18 (N : Integer; Sink : out Integer) is
      X : Integer := 1;
      I : Integer := 0;
   begin
      while I < N loop
         pragma Loop_Invariant (X >= 1);               --  BAD:loop-invariant-preservation
         I := I + 1;
         if I = 7 then
            X := 0;
         end if;
      end loop;
      Sink := 10 / X;
   end C18;

   procedure C19 (N : Integer; Sink : out Integer) is
      X : Integer := N;
   begin
      while X > 0 loop
         pragma Loop_Invariant (X > 0);
         pragma Loop_Variant (Decreases => X);         --  BAD:loop-variant
         if X > 5 then
            X := X - 1;
         end if;
      end loop;
      Sink := X;
   end C19;

   procedure C20 (A, B : Integer; Sink : out Integer) is
   begin
      Sink := 10 / A;                     --  BAD
      Sink := 10 / B;                     --  BAD
   end C20;

   procedure C21 (A, B : in out Integer) is
      T : constant Integer := A;
   begin
      A := B;
      B := T;
   end C21;

   procedure C22 (N : Integer; Sink : out Integer) is
   begin
      G := G - 1;
      Sink := 10 / G + N;                 --  BAD
   end C22;

   procedure C23 (N : Integer; Sink : out Integer) is
      X : Integer := N;
   begin
      pragma Assume (X > 0);
      X := X - 1;
      Sink := 10 / X;
   end C23;

   procedure C24 (N : Integer; Sink : out Integer) is
      X : Integer := N;
   begin
      pragma Assert (X > 0);              --  BAD:assertion
      Sink := 10 / X;                     
      pragma Assert_And_Cut (X /= 5);     --  BAD:assertion
      Sink := 10 / (X - 5);
   end C24;

   procedure C25 (N : Integer; Sink : out Integer) is
      X : Integer := N;
   begin
      for I in 1 .. 3 loop
         pragma Loop_Invariant (X >= N);
         X := X + I;
      end loop;
      pragma Assert (X = N + 6);
      pragma Assert (X = N + 5);          --  BAD:assertion
      Sink := 10 / (X - N - 6);
   end C25;

   procedure C26 (N : Integer; Sink : out Integer) is
      X : Integer := 0;
   begin
      for I in 1 .. 10 loop
         pragma Loop_Invariant (X = I - 1);
         X := X + 1;
         exit when I = N;
      end loop;
      pragma Assert (X = 10);             --  BAD:assertion
      Sink := 10 / (X - 3);
   end C26;

   procedure C27 (N : Integer; Sink : out Integer) is
      X : Integer := 0;
      Y : Integer := 0;
   begin
      for I in 1 .. 10 loop
         pragma Loop_Invariant (X = I - 1);
         X := X + 1;
         if N = I then
            Y := X;
         end if;
      end loop;
      pragma Assert (Y = 0);              --  BAD:assertion
      Sink := 10 / (Y - 4);
   end C27;
end H04;

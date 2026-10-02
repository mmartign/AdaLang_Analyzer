package body H08 with SPARK_Mode is
   procedure Set (A : out Integer; B : out Integer) is
   begin
      A := 1;
      B := 0;
   end Set;

   procedure Dec (X : in out Integer) is
   begin
      X := X - 5;
   end Dec;

   procedure Either (X : out Integer) is
   begin
      X := 0;
   end Either;

   procedure Set_G is
   begin
      G := 0;
   end Set_G;

   procedure Touch_H (X : out Integer) is
   begin
      H := 0;
      X := 1;
   end Touch_H;

   function Nonneg (X : Integer) return Integer is (if X < 0 then 0 else X);

   procedure Swap (A, B : in out Integer) is
      T : constant Integer := A;
   begin
      A := B;
      B := T;
   end Swap;

   procedure Cond (X : in out Integer) is
   begin
      if X > 0 then
         X := 0;
      else
         X := 1;
      end if;
   end Cond;

   procedure T01 (N : Integer; Sink : out Integer) is
      X, Y : Integer;
   begin
      Set (B => Y, A => X);
      Sink := 10 / X + N;                --  OK
      Sink := 10 / Y;                    --  BAD
   end T01;

   procedure T02 (N : Integer; Sink : out Integer) is
      X : Integer := 5 + N - N;
   begin
      Dec (X);
      Sink := 10 / X;                    --  BAD
   end T02;

   procedure T03 (N : Integer; Sink : out Integer) is
      X : Integer;
   begin
      Either (X);
      Sink := 10 / X + N;                --  BAD
   end T03;

   procedure T04 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Set_G;
      Sink := 10 / G + N;                --  BAD
   end T04;

   procedure T05 (N : Integer; Sink : out Integer) is
      X : Integer;
   begin
      H := 5;
      Touch_H (X);
      Sink := 10 / X + N;                --  OK
      Sink := 10 / H;                    --  BAD
   end T05;

   procedure T06 (N : Integer; Sink : out Integer) is
   begin
      Sink := 10 / Nonneg (N);           --  BAD
      Sink := 10 / (Nonneg (N) + 1);     --  OK
      Sink := 10 / (Ident (N) - N + 1);  --  OK
      Sink := 10 / (Ident (N) - N);      --  BAD
   end T06;

   procedure T07 (N : Integer; Sink : out Integer) is
      X : Integer := 5 + N - N;
      Y : Integer := 0;
   begin
      Swap (X, Y);
      Sink := 10 / Y;                    --  OK
      Sink := 10 / X;                    --  BAD
   end T07;

   procedure T08 (N : Integer; Sink : out Integer) is
      X : Integer := 5 + N - N;
   begin
      Cond (X);
      Sink := 10 / X;                    --  BAD
   end T08;

   --  loops over other discrete types
   procedure T09 (N : Integer; Sink : out Integer) is
      B : Byte := 0;
   begin
      Sink := N;
      for I in Byte loop
         B := I + 1;
         Sink := 10 / Integer (B);       --  BAD
      end loop;
      for I in reverse 0 .. 3 loop
         Sink := 10 / (I + 1);           --  OK
         Sink := 10 / I;                 --  BAD
      end loop;
      for I in 3 .. 1 loop
         Sink := 10 / (I - I);
      end loop;
   end T09;

   --  overflow against the right base type
   procedure T10 (N : Integer; Sink : out Integer) is
      X : Small_Range := 10;
      Y : Small_Range;
      type Wide is range 0 .. 2 ** 40;
      W : Wide := 2 ** 40;
   begin
      Y := X + X - X;                    --  OK:range-check
      Y := X + X;                        --  BAD:range-check
      W := W * W / W;                    --  BAD:integer-overflow
      Sink := Integer (Y) + N;
   end T10;

   --  facts through a call that reads but does not write
   procedure T11 (N : Integer; Sink : out Integer) is
      X : Integer := 5 + N - N;
   begin
      Sink := Ident (X);
      Sink := 10 / X;                    --  OK
      G := 5;
      Sink := Ident (G);
      Sink := 10 / G;                    --  OK
   end T11;

   --  comparison of two variables
   procedure T12 (N : Integer; Sink : out Integer) is
      X : Integer := N;
      Y : Integer := 0;
   begin
      Sink := 0;
      if X = Y then
         Sink := 10 / (X + 1);           --  OK
         Sink := 10 / X;                 --  BAD
      end if;
      if X > Y then
         Sink := 10 / X;                 --  OK
         Sink := 10 / (X - 1);           --  BAD
      end if;
      if X /= Y then
         Sink := 10 / X;                 --  OK
      else
         Sink := 10 / X;                 --  BAD
      end if;
   end T12;

   --  assertions that restrict, then a change
   procedure T13 (N : Integer; Sink : out Integer) is
      X : Integer := N;
   begin
      pragma Assume (X > 0);
      Sink := 10 / X;                    --  OK
      X := X - 1;
      Sink := 10 / X;                    --  BAD
      pragma Assume (X in 1 .. 5);
      X := X * 2 - 4;
      Sink := 10 / X;                    --  BAD
   end T13;

   --  exits from nested loops with the same variable
   procedure T14 (N : Integer; Sink : out Integer) is
      X : Integer := 1;
   begin
      for I in 1 .. 3 loop
         X := 1;
         for J in 1 .. 3 loop
            X := X - 1;
            exit when J = N;
            X := X + 1;
         end loop;
         Sink := 10 / X;                 --  BAD
      end loop;
      Sink := 10 / X;                    --  BAD
   end T14;

   --  while loop with a compound guard
   procedure T15 (N : Integer; Sink : out Integer) is
      X : Integer := 10;
      I : Integer := 0;
   begin
      while X > 0 and then I < N loop
         X := X - 3;
         I := I + 1;
      end loop;
      Sink := 10 / (X - 1);              --  BAD
      Sink := 10 / (X + 3);              --  BAD
      Sink := 10 / (X - 11);             --  OK
   end T15;

   --  array elements
   procedure T16 (A : Arr; N : Integer; Sink : out Integer) is
      B : Arr := A;
   begin
      Sink := 0;
      if A (1) /= 0 then
         Sink := 10 / A (1);             --  OK
         Sink := 10 / A (2);             --  BAD
      end if;
      B (1) := 5;
      B (2) := 0;
      Sink := 10 / B (1);                --  OK
      Sink := 10 / B (2);                --  BAD
      if N in 1 .. 4 then
         B (N) := 0;
         Sink := 10 / B (1);             --  BAD
      end if;
      pragma Assert (for all I in A'Range => A (I) > 0);
      Sink := 10 / A (3);                --  OK
      Sink := 10 / (A (3) - 1);          --  BAD
   end T16;

   --  values after a case with ranges
   procedure T17 (N : Integer; Sink : out Integer) is
      X : Integer;
   begin
      case N is
         when Integer'First .. -1 => X := -1;
         when 0 => X := N;
         when 1 .. 9 => X := N - 9;
         when others => X := N;
      end case;
      Sink := 10 / X;                    --  BAD
      if N > 9 then
         Sink := 10 / X;                 --  OK
      end if;
      if N in 1 .. 8 then
         Sink := 10 / X;                 --  OK
      end if;
   end T17;

   --  modular loop counter that wraps
   procedure T18 (N : Integer; Sink : out Integer) is
      B : Byte := 250;
   begin
      Sink := N;
      for I in 1 .. 6 loop
         B := B + 1;
      end loop;
      Sink := 10 / Integer (B);          --  BAD
      B := 250;
      while B /= 0 loop
         Sink := 10 / Integer (B);       --  OK
         B := B + 1;
      end loop;
      Sink := 10 / Integer (B + 1);      --  OK
      Sink := 10 / Integer (B);          --  BAD
   end T18;
end H08;

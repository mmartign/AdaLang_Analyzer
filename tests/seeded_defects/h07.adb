package body H07 is
   overriding procedure Finalize (Object : in out Ctrl) is
   begin
      G := 0;
   end Finalize;

   overriding procedure Initialize (Object : in out Ctrl) is
   begin
      G := 0;
   end Initialize;

   protected body Guard is
      procedure Set (V : Integer) is
      begin
         Value := V;
      end Set;
      function Get return Integer is (Value);
   end Guard;

   function Zero_G return Integer is
   begin
      G := 0;
      return 1;
   end Zero_G;

   procedure Takes_Small (X : Small) is null;

   procedure Gives_Big (X : out Integer) is
   begin
      X := 100;
   end Gives_Big;

   --  by-reference formals that may denote one object
   procedure Two (R1, R2 : in out Rec; Sink : out Integer) is
   begin
      R1.A := 5;
      R2.A := 0;
      Sink := 10 / R1.A;                 --  BAD
   end Two;

   --  non-short-circuit operators evaluate both operands
   procedure S01 (N : Integer; Sink : out Integer) is
   begin
      Sink := 0;
      if N > 0 and (10 / N) > 1 then     --  BAD
         Sink := 1;
      end if;
      if N <= 0 or (10 / N) > 1 then     --  BAD
         Sink := 2;
      end if;
      if N > 0 and then (10 / N) > 1 then   --  OK
         Sink := 3;
      end if;
   end S01;

   --  finalization with a side effect
   procedure S02 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      declare
         Obj : Ctrl;
      begin
         G := 5 + N - N;
      end;
      Sink := 10 / G;                    --  BAD
   end S02;

   procedure S03 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      declare
         Obj : Ctrl;
         pragma Unreferenced (Obj);
      begin
         Sink := 10 / G + N;             --  BAD
      end;
   end S03;

   --  default initialization that calls a function
   procedure S04 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      declare
         W : With_Default;
      begin
         Sink := 10 / G + W.F + N;       --  BAD
      end;
   end S04;

   --  protected state changed by anybody
   procedure S05 (N : Integer; Sink : out Integer) is
      V : Integer;
   begin
      Guard.Set (5);
      V := Guard.Get;
      Sink := N;
      if Guard.Get > 0 then
         Sink := 10 / Guard.Get;         --  BAD
      end if;
      Sink := Sink + V;
   end S05;

   --  a task that writes a local
   procedure S06 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
      task Worker;
      task body Worker is
      begin
         X := 0;
      end Worker;
   begin
      delay 0.0;
      Sink := 10 / X + N;                --  BAD
   end S06;

   --  truncating division and the signs of mod / rem
   procedure S07 (N : Integer; Sink : out Integer) is
   begin
      Sink := 0;
      if N in -9 .. -1 then

         pragma Assert (N / 2 * 2 <= N);        --  BAD:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert (N / 2 * 2 >= N);        --  OK:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert (N rem 2 >= 0);          --  BAD:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert (N rem 2 <= 0);          --  OK:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert (N mod 2 >= 0);          --  OK:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert (N mod (-2) >= 0);       --  BAD:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert (N mod (-2) <= 0);       --  OK:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert ((-N) / (-2) = N / 2);   --  BAD:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert (-7 / 2 = -3);           --  OK:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert (-7 / 2 = -4);           --  BAD:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert ((-7) mod 2 = 1);        --  OK:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert ((-7) rem 2 = 1);        --  BAD:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert (7 mod (-2) = 1);        --  BAD:assertion
      end if;
      if N in -9 .. -1 then
         pragma Assert (7 rem (-2) = -1);       --  BAD:assertion
      end if;
      if N in -9 .. -1 then
         null;
      end if;
   end S07;

   --  attributes
   procedure S08 (N : Integer; Sink : out Integer) is
      C : Colour := Green;
   begin
      Sink := 0;
      if N in 0 .. 2 then
         C := Colour'Val (N);
         pragma Assert (C = Green);                       --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (Colour'Pos (C) = N);              --  OK:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (Colour'Pos (C) = 1);              --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (Integer'Max (N, 1) = N);          --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (Integer'Min (N, 1) = N);          --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (Integer'Succ (N) = N - 1);        --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (Integer'Pred (N) = N + 1);        --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (C in Red .. Green);               --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (Colour'Succ (Red) = Blue);        --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (Colour'First = Green);            --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (Colour'Last = Green);             --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (C < Blue);                        --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         pragma Assert (abs N = -N);                      --  BAD:assertion
      end if;
      if N in 0 .. 2 then
         null;
      end if;
   end S08;

   --  parameter passing checks
   procedure S09 (N : Integer; Sink : out Integer) is
      S : Small := 0;
   begin
      Takes_Small (N);                   --  BAD:range-check
      Takes_Small (11 + N - N);          --  BAD:range-check
      Gives_Big (S);                     --  BAD:range-check
      Sink := S;
   end S09;

   --  record assignment through another name
   procedure S10 (N : Integer; Sink : out Integer) is
      R : Rec;
   begin
      R.A := 5;
      Two (R, R, Sink);
      Sink := 10 / R.A + N;              --  BAD
   end S10;

   --  if / case expressions
   procedure S11 (N : Integer; Sink : out Integer) is
      X : constant Integer := (if N > 0 then N else 0);
      Y : constant Integer := (case N is when 1 => 0, when 2 => 2, when others => 3);
   begin
      Sink := 10 / X;                    --  BAD
      Sink := 10 / Y;                    --  BAD
      Sink := 10 / (if N > 0 then N else 1);   --  OK
      Sink := (if N /= 0 then 10 / N else 10 / (N + 1));
      Sink := (if N > 0 then 10 / (N - 1) else 0);   --  BAD
   end S11;

   --  boolean tracking
   procedure S12 (N : Integer; Sink : out Integer) is
      Ok : Boolean := N > 0;
      X  : Integer := N;
   begin
      Sink := 0;
      X := X - 1;
      if Ok then
         Sink := 10 / X;                 --  BAD
      end if;
      Ok := X /= 0;
      X := X - 1;
      if Ok then
         Sink := 10 / X;                 --  BAD
      end if;
   end S12;

   --  facts about a variable captured in another, then the first changes
   procedure S13 (N : Integer; Sink : out Integer) is
      X : Integer := N;
      Y : Integer;
   begin
      Sink := 0;
      Y := X;
      if Y > 0 then
         X := X - 5;
         Sink := 10 / X;                 --  BAD
         Sink := 10 / Y;                 --  OK
      end if;
      Y := X + 1;
      X := X + 1;
      if Y = X then
         Sink := 10 / (Y - X + 1);       --  OK
      else
         Sink := 10 / (N - N);           --  OK
      end if;
      if Y = 1 then
         Sink := 10 / (X - 1);           --  BAD
      end if;
   end S13;

   --  loop that re-elaborates a constant
   procedure S14 (N : Integer; Sink : out Integer) is
   begin
      Sink := 0;
      for I in 0 .. 3 loop
         declare
            C : constant Integer := I + N - N;
         begin
            Sink := Sink + 10 / (C + 1);    --  OK
            Sink := Sink + 10 / C;          --  BAD
         end;
      end loop;
   end S14;

   --  enumeration case coverage
   procedure S15 (N : Integer; C : Colour; Sink : out Integer) is
      X : Integer := 0;
   begin
      case C is
         when Red => X := 1;
         when Green => X := 2;
         when Blue => X := N - N;
      end case;
      Sink := 10 / X;                    --  BAD
      case C is
         when Red | Green => X := 1;
         when others => X := 0;
      end case;
      Sink := 10 / X;                    --  BAD
   end S15;

   --  call inside a loop changes a global
   procedure S16 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := 0;
      for I in 1 .. N loop
         Sink := Sink + 10 / G;          --  BAD
         if I = 2 then
            Sink := Sink + Zero_G;
         end if;
      end loop;
   end S16;

   --  overflow guards that do not guard
   procedure S17 (N : Integer; Sink : out Integer) is
   begin
      Sink := 0;
      if N < Integer'Last then
         Sink := N + 1;                  --  OK:integer-overflow
         Sink := N + 2;                  --  BAD:integer-overflow
      end if;
      if N > 0 then
         Sink := N * 2;                  --  BAD:integer-overflow
         Sink := N - Integer'First;      --  BAD:integer-overflow
      end if;
      if N in -10 .. 10 then
         Sink := N * N * N * N * N * N * N * N * N * N;
      end if;
   end S17;

   --  exit condition facts
   procedure S18 (N : Integer; Sink : out Integer) is
      I : Integer := 0;
   begin
      loop
         exit when I >= N;
         I := I + 3;
      end loop;
      Sink := 10 / (I - N + 1);          --  OK
      Sink := 10 / (I - N);              --  BAD
      Sink := 10 / (I - N - 2);          --  BAD
   end S18;

   --  shadowing
   procedure S19 (N : Integer; Sink : out Integer) is
      G : Integer := 5;
   begin
      H07.G := 0;
      Sink := 10 / G + N;                --  OK
      Sink := 10 / H07.G;                --  BAD
   end S19;

   --  return in the middle of a block with a handler
   procedure S20 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      Sink := 0;
      begin
         if N > 0 then
            X := 0;
            raise Constraint_Error;
         end if;
         X := 1;
      exception
         when Constraint_Error =>
            Sink := 10 / X;              --  BAD
      end;
   end S20;
end H07;

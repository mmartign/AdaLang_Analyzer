package body H02 is
   procedure Might_Raise (V : Integer) is
   begin
      if V > 3 then
         raise Failed;
      end if;
   end Might_Raise;

   procedure F01 (N : Integer; Sink : out Integer) is
      S : Small := 0;
   begin
      for I in 1 .. 20 loop
         S := I;                      --  BAD:range-check
      end loop;
      Sink := S + N;
   end F01;

   procedure F02 (N : Integer; Sink : out Integer) is
      S : Small := 0;
      X : Integer := 0;
   begin
      while X < 10 loop
         X := X + 7;
         S := X;                      --  BAD:range-check
      end loop;
      Sink := S + N;
   end F02;

   procedure F03 (N : Integer; Sink : out Integer) is
      S : Small := 0;
      X : Integer := 0;
   begin
      while X < 10 loop
         X := X + 7;
      end loop;
      S := X;                         --  BAD:range-check
      Sink := S + N;
   end F03;

   procedure F04 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      Sink := 0;
      for I in 1 .. N loop
         Sink := 10 / X;              --  BAD
         X := X - 1;
      end loop;
   end F04;

   procedure F05 (N : Integer; Sink : out Integer) is
      Y : Integer := 5;
   begin
      for I in 1 .. N loop
         exit when I > 3;
         Y := 0;
      end loop;
      Sink := 10 / Y;                 --  BAD
   end F05;

   procedure F06 (N : Integer; M : Integer; Sink : out Integer) is
      Y : Integer := 5;
   begin
      Sink := M;
      begin
         Y := 0;
         Might_Raise (N);
         Y := 5;
      exception
         when Failed =>
            Sink := 10 / Y;           --  BAD
      end;
   end F06;

   procedure F07 (N : Integer; Sink : out Integer) is
      Y : Integer := 5;
   begin
      begin
         Y := 0;
         Might_Raise (N);
         Y := 5;
      exception
         when Failed =>
            null;
      end;
      Sink := 10 / Y;                 --  BAD
   end F07;

   procedure F08 (N : Integer; M : Integer; Sink : out Integer) is
      Y : Integer := 5;
   begin
      Sink := N;
      begin
         Y := 0;
         Sink := 10 / M;
         Y := 5;
      exception
         when Constraint_Error =>
            null;
      end;
      Sink := 10 / Y;                 --  BAD
   end F08;

   procedure F09 (N : Integer; M : Integer; Sink : out Integer) is
      Y : Integer := 5;
      A : array (1 .. 3) of Integer := (others => 1);
   begin
      Sink := N;
      begin
         Y := 0;
         Sink := A (M);
         Y := 5;
      exception
         when others =>
            null;
      end;
      Sink := 10 / Y;                 --  BAD
   end F09;

   procedure F10 (N : Integer; Sink : out Integer) is
      X : constant Integer := N;
   begin
      case X is
         when 1 .. 5 =>
            Sink := 10 / (X - 3);     --  BAD
         when 7 | 9 =>
            Sink := 10 / (X - 9);     --  BAD
         when others =>
            Sink := 10 / X;           --  BAD
      end case;
   end F10;

   procedure F11 (N : Integer; Sink : out Integer) is
      M : constant Integer := N / 2;
   begin
      Sink := 0;
      if N > 0 or else M > 0 then
         Sink := 10 / N;              --  OK
      end if;
      if N > 0 or M > 5 then
         Sink := 10 / (N - 1);        --  BAD
      end if;
      if not (N > 0 and then M > 0) then
         Sink := 10 / (N - 5);        --  OK
      end if;
      if not (N > 0 or else M > 0) then
         Sink := 10 / (N - 1);        --  OK
         Sink := 10 / N;              --  BAD
      end if;
   end F11;

   procedure F12 (N : Integer; Sink : out Integer) is
      X : Integer;
   begin
      if N > 0 then
         X := N;
      elsif N < -5 then
         X := -N;
      else
         X := 1;
         Sink := 10 / N;              --  BAD
      end if;
      Sink := 10 / X;                 --  OK
   end F12;

   procedure F13 (N : Integer; Sink : out Integer) is
      X : Integer := N;
   begin
      Sink := 0;
      if X > 0 then
         X := X - 1;
         Sink := 10 / X;              --  BAD
      end if;
   end F13;

   procedure F14 (N : Integer; Sink : out Integer) is
      X : Integer := 1;
   begin
      Outer :
      for I in 1 .. 3 loop
         for J in 1 .. 3 loop
            if J = N then
               X := 0;
               exit Outer;
            end if;
         end loop;
      end loop Outer;
      Sink := 10 / X;                 --  BAD
   end F14;

   procedure F15 (N : Integer; Sink : out Integer) is
      X : Integer := 1;
   begin
      loop
         X := X - 1;
         exit when X <= N;
         X := X + 2;
         exit when X > 100;
      end loop;
      Sink := 10 / X;                 --  BAD
   end F15;

   procedure F16 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      Sink := 0;
      if N > 3 then
         X := 0;
         return;
      end if;
      if N = 2 then
         X := N - 2;
      end if;
      Sink := 10 / X;                 --  BAD
   end F16;

   procedure F17 (N : Integer; Sink : out Integer) is
      X : Integer := N;
   begin
      Sink := 0;
      if X /= 0 then
         X := X / 2;
         Sink := 10 / X;              --  BAD
      end if;
   end F17;

   procedure F18 (N : Integer; Sink : out Integer) is
      X : Integer := N;
   begin
      Sink := 0;
      while X /= 0 loop
         Sink := Sink + 10 / X;       --  OK
         X := X / 2;
      end loop;
      Sink := 10 / (X + 1);           --  OK
      Sink := 10 / X;                 --  BAD
   end F18;

   procedure F19 (N : Integer; Sink : out Integer) is
      X : Integer := 3;
   begin
      Sink := 0;
      for I in reverse 0 .. 3 loop
         Sink := 10 / (I + N - N);    --  BAD
         X := I;
      end loop;
      Sink := 10 / X;                 --  BAD
   end F19;

   procedure F20 (N : Integer; Sink : out Integer) is
      X : Integer := 1;
   begin
      for I in 1 .. 0 loop
         X := 0;
      end loop;
      Sink := 10 / X;                 --  OK
      for I in 1 .. N loop
         X := 0;
      end loop;
      Sink := 10 / X;                 --  BAD
   end F20;

   procedure F21 (N : Integer; Sink : out Integer) is
      X : Integer := N;
   begin
      Sink := 0;
      if X in 1 .. 5 then
         X := X - 1;
      end if;
      if X = 0 then
         return;
      end if;
      Sink := 10 / X;                 --  OK
      X := X - 1;
      Sink := 10 / X;                 --  BAD
   end F21;

   procedure F22 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
      Y : Integer := 0;
   begin
      declare
         X : Integer := 0;
      begin
         Y := X + N - N;
      end;
      Sink := 10 / X;                 --  OK
      Sink := 10 / Y;                 --  BAD
   end F22;

   procedure F23 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      Sink := 0;
      for I in 1 .. 3 loop
         if I = 3 and then N > 0 then
            X := 0;
         end if;
      end loop;
      Sink := 10 / X;                 --  BAD
   end F23;

   procedure F24 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
      I : Integer := 0;
   begin
      Sink := 0;
      while I < N loop
         I := I + 1;
         if I = 100 then
            X := 0;
         end if;
      end loop;
      Sink := 10 / X;                 --  BAD
   end F24;

   procedure F25 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      Sink := 0;
      begin
         if N > 0 then
            X := 0;
            raise Failed;
         end if;
      exception
         when Failed =>
            Sink := 1;
      end;
      Sink := 10 / X;                 --  BAD
   end F25;

   function F26 (N : Integer) return Small is
   begin
      if N > 20 then
         return N;                    --  BAD:range-check
      end if;
      return 11 + N - N;              --  BAD:range-check
   end F26;

   function F27 (N : Integer) return Integer is
      X : Integer := 5;
   begin
      if N > 0 then
         X := 0;
      end if;
      return 10 / X;                  --  BAD
   end F27;

   procedure F28 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      Sink := 0;
      for I in 1 .. 2 loop
         begin
            X := I - 1;
            Might_Raise (N);
            X := 5;
         exception
            when Failed =>
               null;
         end;
         Sink := Sink + 10 / X;       --  BAD
      end loop;
   end F28;

   procedure F29 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      Sink := 0;
      begin
         X := 0;
         Might_Raise (N);
      exception
         when Failed =>
            X := 0;
            raise;
      end;
      Sink := 10 / X;                 --  BAD
   end F29;

   procedure F30 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      Sink := 0;
      Block :
      declare
         Y : Integer := N;
      begin
         if Y > 0 then
            X := 0;
         end if;
      exception
         when others =>
            null;
      end Block;
      Sink := 10 / X;                 --  BAD
   end F30;
end H02;

package body H05 with SPARK_Mode is
   --  Valid invariant; the last iteration breaks it after the last check.
   procedure L01 (N : Integer; Sink : out Integer) is
      X : Integer := 1;
      I : Integer := 0;
   begin
      while I < N loop
         pragma Loop_Invariant (X = 1);
         I := I + 1;
         if I = N then
            X := 0;
         end if;
      end loop;
      Sink := 10 / X;                     --  BAD
   end L01;

   procedure L02 (N : Integer; Sink : out Integer) is
      X : Integer := 1;
   begin
      for I in 1 .. 10 loop
         pragma Loop_Invariant (X = 1);
         if I = 10 then
            X := 0;
         end if;
      end loop;
      Sink := 10 / X + N;                 --  BAD
   end L02;

   procedure L03 (N : Integer; Sink : out Integer) is
      X : Integer := 0;
   begin
      for I in 1 .. 10 loop
         pragma Loop_Invariant (X = I - 1);
         X := X + 1;
         exit when I = N;
      end loop;
      Sink := 10 / (X - 3);               --  BAD
      Sink := 10 / (X - 10);              --  BAD
      Sink := 10 / (X + 1);               --  OK
   end L03;

   procedure L04 (N : Integer; Sink : out Integer) is
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
      Sink := 10 / (Y - 4);               --  BAD
   end L04;

   procedure L05 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      for I in 1 .. N loop
         pragma Loop_Invariant (X = 5);
         X := 5;
      end loop;
      Sink := 10 / X;                     --  OK
      for I in 1 .. N loop
         pragma Loop_Invariant (X >= 5);
         X := X + 1;
         exit when X > 7;
         X := X - 8;
         X := X + 8;
      end loop;
      Sink := 10 / (X - 8);               --  BAD
   end L05;

   procedure L06 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
      I : Integer := 0;
   begin
      loop
         pragma Loop_Invariant (X = 5);
         I := I + 1;
         if I > N then
            X := 0;
            exit;
         end if;
      end loop;
      Sink := 10 / X;                     --  BAD
   end L06;

   procedure L07 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
      I : Integer := 0;
   begin
      while I < 3 loop
         X := 0;
         pragma Loop_Invariant (X = 0);
         I := I + 1;
         X := 5;
      end loop;
      Sink := 10 / X + N;                 --  OK
   end L07;

   procedure L08 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
      I : Integer := 0;
   begin
      while I < N loop
         X := 5;
         pragma Loop_Invariant (X = 5);
         I := I + 1;
         X := 0;
      end loop;
      Sink := 10 / X;                     --  BAD
   end L08;

   procedure L09 (N : Integer; Sink : out Integer) is
      X : Integer := 0;
   begin
      for I in 1 .. N loop
         pragma Loop_Invariant (X = I - 1);
         X := X + 1;
      end loop;
      Sink := 10 / X;                     --  BAD
   end L09;

   procedure L10 (N : Integer; Sink : out Integer) is
      X : Integer := 0;
      I : Integer := 0;
   begin
      while I < 10 loop
         pragma Loop_Invariant (X = I);
         pragma Loop_Variant (Increases => I);
         X := X + 1;
         I := I + 1;
      end loop;
      Sink := 10 / (X - 10) + N;          --  BAD
   end L10;

   procedure L11 (N : Integer; Sink : out Integer) is
      X : Integer := 1;
   begin
      for I in 1 .. 3 loop
         for J in 1 .. 3 loop
            pragma Loop_Invariant (X = 1);
            if I = 3 and then J = 3 then
               X := 0;
            end if;
         end loop;
      end loop;
      Sink := 10 / X + N;                 --  BAD
   end L11;

   procedure L12 (N : Integer; Sink : out Integer) is
      X : Integer := 1;
      Y : Integer := 1;
   begin
      for I in 1 .. N loop
         pragma Loop_Invariant (X = 1);
         Y := 0;
      end loop;
      Sink := 10 / Y;                     --  BAD
   end L12;
end H05;

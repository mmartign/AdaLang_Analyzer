package body H13 is
   procedure B01 (A : String; I : Integer; Sink : out Integer) is
   begin
      Sink := Character'Pos (A (I));              --  OK:index-check
      Sink := Character'Pos (A (I + 1));          --  BAD:index-check
      Sink := Character'Pos (A (I - 1));          --  BAD:index-check
      Sink := Character'Pos (A (A'First));        --  OK:index-check
   end B01;

   procedure B02 (A : String; B : String; I : Integer; Sink : out Integer) is
   begin
      Sink := Character'Pos (B (I));              --  BAD:index-check
      Sink := Character'Pos (A (I));              --  OK:index-check
   end B02;

   procedure B03 (A : String; Sink : out Integer) is
   begin
      Sink := 0;
      for K in A'First .. A'Last - 1 loop
         Sink := Character'Pos (A (K + 1));       --  OK:index-check
         Sink := Character'Pos (A (K + 2));       --  BAD:index-check
         Sink := Character'Pos (A (K));           --  OK:index-check
      end loop;
      for K in A'First + 1 .. A'Last loop
         Sink := Character'Pos (A (K - 1));       --  OK:index-check
         Sink := Character'Pos (A (K - 2));       --  BAD:index-check
      end loop;
      if A'Length > 0 then
         Sink := Character'Pos (A (A'First));     --  OK:index-check
         Sink := Character'Pos (A (A'Last));      --  OK:index-check
         Sink := Character'Pos (A (A'First + 1)); --  BAD:index-check
      end if;
      Sink := Character'Pos (A (A'First));        --  BAD:index-check
      if A'Length > 1 then
         Sink := Character'Pos (A (A'First + 1)); --  OK:index-check
         Sink := Character'Pos (A (A'Last - 1));  --  OK:index-check
         Sink := Character'Pos (A (A'Last + 1));  --  BAD:index-check
      end if;
   end B03;

   procedure B04 (A : String; J : Integer; Sink : out Integer) is
   begin
      Sink := 0;
      if J >= A'First and then J <= A'Last then
         Sink := Character'Pos (A (J));           --  OK:index-check
      end if;
      if J >= A'First then
         Sink := Character'Pos (A (J));           --  BAD:index-check
      end if;
      if J in A'Range then
         Sink := Character'Pos (A (J));           --  OK:index-check
      else
         Sink := Character'Pos (A (J));           --  BAD:index-check
      end if;
   end B04;

   procedure B05 (A : in out String; I : Integer; Sink : out Integer) is
      K : Integer := I;
   begin
      A (I) := 'x';                               --  OK:index-check
      A (I + 1) := 'y';                           --  OK:index-check
      K := K + 2;
      Sink := Character'Pos (A (K));              --  BAD:index-check
   end B05;

   procedure B06 (R1, R2 : Rec; Sink : out Integer) is
   begin
      Sink := 0;
      pragma Assert (R1.Data'Length = R2.Data'Length);   --  BAD:assertion
      pragma Assert (R1.Data'Last = R2.Data'Last);       --  BAD:assertion
   end B06;

   procedure B07 (A : String; N : Integer; Sink : out Integer) is
      M : Integer := N;
   begin
      Sink := 0;
      for K in A'First .. M loop
         M := M + 1;
         Sink := Character'Pos (A (K));           --  BAD:index-check
      end loop;
      M := A'Last;
      for K in A'First .. M loop
         Sink := Character'Pos (A (K));
         M := M + 5;
      end loop;
   end B07;

   procedure B08 (A : String; B : String; Sink : out Integer) is
   begin
      Sink := 0;
      for K in A'Range loop
         Sink := Character'Pos (B (K));           --  OK:index-check
         Sink := Character'Pos (B (K + 1));       --  BAD:index-check
      end loop;
   end B08;

   procedure B09 (A : String; I : Integer; Sink : out Integer) is
      X : Integer := I;
   begin
      Sink := Character'Pos (A (X));              --  OK:index-check
      X := X + 1;
      Sink := Character'Pos (A (X));              --  BAD:index-check
   end B09;
end H13;

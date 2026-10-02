package body H09 is
   function Reset return Integer is
   begin
      G := 0;
      return 1;
   end Reset;

   function Reset_With (X : Integer := Reset) return Integer is (X);

   function Reset_Out (X : out Integer) return Integer is
   begin
      X := 0;
      return 1;
   end Reset_Out;

   function "+" (L, R : Money) return Money is
   begin
      G := 0;
      return Money (Integer (L) + Integer (R));
   end "+";

   function Gen_Reset return Integer is
   begin
      G := 0;
      return 1;
   end Gen_Reset;

   procedure U01 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Alias_G := N - N;
      Sink := 10 / G;                    --  BAD
   end U01;

   procedure U02 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Over_G := N - N;
      Sink := 10 / G;                    --  BAD
   end U02;

   procedure U03 (N : Integer; Sink : out Integer) is
   begin
      Sink := N;
      P_Vol := 5;
      Sink := 10 / P_Vol;                --  BAD
      P_Atom := 5;
      Sink := 10 / P_Atom;               --  BAD
      T_Vol := 5;
      Sink := 10 / Integer (T_Vol);      --  BAD
      Imported := 5;
      Sink := 10 / Imported;             --  BAD
   end U03;

   procedure U04 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := Reset_With + N;
      Sink := 10 / G;                    --  BAD
   end U04;

   procedure U05 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      Sink := Reset_Out (X) + N;
      Sink := 10 / X;                    --  BAD
   end U05;

   procedure U06 (N : Integer; Sink : out Integer) is
      A : Money := 1;
   begin
      G := 5;
      A := A + A;
      Sink := 10 / G + Integer (A) + N;  --  BAD
   end U06;

   procedure U07 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := Renamed_Reset + N;
      Sink := 10 / G;                    --  BAD
   end U07;

   procedure U08 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := Inst_Reset + N;
      Sink := 10 / G;                    --  BAD
   end U08;

   procedure U09 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := N;
      for I in 1 .. Reset loop
         Sink := 10 / G;                 --  BAD
      end loop;
   end U09;

   procedure U10 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := N;
      while Reset > N loop
         Sink := 10 / G;                 --  BAD
         exit;
      end loop;
      Sink := 10 / G;                    --  BAD
   end U10;

   procedure U11 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := N;
      loop
         exit when Reset = 1;
      end loop;
      Sink := 10 / G;                    --  BAD
   end U11;

   procedure U12 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      case Reset is
         when 1 => Sink := 10 / G;       --  BAD
         when others => Sink := N;
      end case;
   end U12;

   procedure U13 (N : Integer; Sink : out Integer) is
      A : Arr := (others => 1);
   begin
      G := 5;
      A (Reset) := N;
      Sink := 10 / G + A (1);            --  BAD
   end U13;

   procedure U14 (N : Integer; Sink : out Integer) is
      A : constant Arr := (1 => Reset, others => N);
   begin
      Sink := 10 / G + A (1);            --  BAD
   end U14;

   procedure U15 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := (if N > 0 then Reset else 1);
      Sink := 10 / G;                    --  BAD
   end U15;

   procedure U16 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := N;
      if N > 0 and then Reset = 1 then
         Sink := 10 / G;                 --  BAD
      end if;
      Sink := 10 / G;                    --  BAD
   end U16;

   function U17 (N : Integer) return Integer is
   begin
      G := 5;
      return Reset + 10 / G + N;         --  BAD
   end U17;

   procedure U18 (N : Integer; Sink : out Integer) is
      L : Integer := 5;
      R : Integer renames L;
      S : Integer renames R;
   begin
      L := 5;
      S := N - N;
      Sink := 10 / L;                    --  BAD
   end U18;

   procedure U19 (P : in out Integer; Sink : out Integer) is
      R : Integer renames P;
   begin
      P := 5;
      R := 0;
      Sink := 10 / P;                    --  BAD
   end U19;

   procedure U20 (N : Integer; Sink : out Integer) is
      X : aliased Integer := 5;
      type Ptr is access all Integer;
      procedure Poke (Where : Ptr) is
      begin
         Where.all := 0;
      end Poke;
   begin
      X := 5;
      Poke (X'Access);
      Sink := 10 / X + N;                --  BAD
   end U20;
end H09;

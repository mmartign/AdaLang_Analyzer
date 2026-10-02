package body H10 is
   procedure Gen_Zero is
   begin
      G := 0;
   end Gen_Zero;

   procedure Gen_Clear (X : out T) is
   begin
      X := T'First;
      G := 0;
   end Gen_Clear;

   package body Gen_Pkg is
      procedure Zero is
      begin
         G := 0;
      end Zero;
      function Zero_Fn return Integer is
      begin
         G := 0;
         return 1;
      end Zero_Fn;
   end Gen_Pkg;

   procedure V01 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Inst_Zero;
      Sink := 10 / G + N;                --  BAD
   end V01;

   procedure V02 (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      G := 5;
      Clear_Int (X);
      Sink := 10 / G + N;                --  BAD
      Sink := 10 / (X + 5);              
   end V02;

   procedure V03 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Inst_Pkg.Zero;
      Sink := 10 / G + N;                --  BAD
   end V03;

   procedure V04 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := Inst_Pkg.Zero_Fn + N;
      Sink := 10 / G;                    --  BAD
   end V04;

   procedure V05 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Renamed_Zero;
      Sink := 10 / G + N;                --  BAD
   end V05;
end H10;

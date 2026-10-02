package H10 is
   G : Integer := 5;
   generic
   procedure Gen_Zero;
   procedure Inst_Zero is new Gen_Zero;
   generic
      type T is range <>;
   procedure Gen_Clear (X : out T);
   procedure Clear_Int is new Gen_Clear (Integer);
   generic
   package Gen_Pkg is
      procedure Zero;
      function Zero_Fn return Integer;
   end Gen_Pkg;
   package Inst_Pkg is new Gen_Pkg;
   procedure Renamed_Zero renames Inst_Zero;
   procedure V01 (N : Integer; Sink : out Integer);
   procedure V02 (N : Integer; Sink : out Integer);
   procedure V03 (N : Integer; Sink : out Integer);
   procedure V04 (N : Integer; Sink : out Integer);
   procedure V05 (N : Integer; Sink : out Integer);
end H10;

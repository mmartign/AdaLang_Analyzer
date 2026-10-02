package H08 with SPARK_Mode is
   type Byte is mod 256;
   type Arr is array (1 .. 4) of Integer;
   type Small_Range is range 1 .. 10;
   G : Integer := 0;
   H : Integer := 0;
   procedure Set (A : out Integer; B : out Integer)
     with Global => null, Post => A = 1 and then B = 0;
   procedure Dec (X : in out Integer)
     with Global => null, Pre => X >= -100, Post => X = X'Old - 5;
   procedure Either (X : out Integer)
     with Global => null, Post => X > 0 or else X = 0;
   procedure Set_G
     with Global => (Output => G), Post => G = 0;
   procedure Touch_H (X : out Integer)
     with Global => (In_Out => H), Post => X = 1;
   function Nonneg (X : Integer) return Integer
     with Global => null, Post => Nonneg'Result >= 0;
   function Ident (X : Integer) return Integer is (X) with Global => null;
   procedure Swap (A, B : in out Integer)
     with Global => null, Post => A = B'Old and then B = A'Old;
   procedure Cond (X : in out Integer)
     with Global => null,
          Contract_Cases => (X > 0 => X = 0, others => X = 1);
   procedure T01 (N : Integer; Sink : out Integer);
   procedure T02 (N : Integer; Sink : out Integer);
   procedure T03 (N : Integer; Sink : out Integer);
   procedure T04 (N : Integer; Sink : out Integer);
   procedure T05 (N : Integer; Sink : out Integer);
   procedure T06 (N : Integer; Sink : out Integer);
   procedure T07 (N : Integer; Sink : out Integer);
   procedure T08 (N : Integer; Sink : out Integer);
   procedure T09 (N : Integer; Sink : out Integer);
   procedure T10 (N : Integer; Sink : out Integer);
   procedure T11 (N : Integer; Sink : out Integer);
   procedure T12 (N : Integer; Sink : out Integer);
   procedure T13 (N : Integer; Sink : out Integer);
   procedure T14 (N : Integer; Sink : out Integer);
   procedure T15 (N : Integer; Sink : out Integer);
   procedure T16 (A : Arr; N : Integer; Sink : out Integer);
   procedure T17 (N : Integer; Sink : out Integer);
   procedure T18 (N : Integer; Sink : out Integer);
end H08;

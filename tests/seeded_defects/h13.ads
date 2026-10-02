package H13 is
   type Rec (Len : Natural) is record
      Data : String (1 .. Len);
   end record;
   procedure B01 (A : String; I : Integer; Sink : out Integer) with Pre => I in A'Range;
   procedure B02 (A : String; B : String; I : Integer; Sink : out Integer) with Pre => I in A'Range;
   procedure B03 (A : String; Sink : out Integer);
   procedure B04 (A : String; J : Integer; Sink : out Integer);
   procedure B05 (A : in out String; I : Integer; Sink : out Integer) with Pre => I >= A'First and then I < A'Last;
   procedure B06 (R1, R2 : Rec; Sink : out Integer);
   procedure B07 (A : String; N : Integer; Sink : out Integer);
   procedure B08 (A : String; B : String; Sink : out Integer) with Pre => A'Length = B'Length and then A'First = B'First;
   procedure B09 (A : String; I : Integer; Sink : out Integer) with Pre => I in A'First .. A'Last;
end H13;

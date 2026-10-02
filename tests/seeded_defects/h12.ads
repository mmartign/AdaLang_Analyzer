package H12 is
   G : Integer := 5;
   type Rec is record
      F : Integer := 1;
   end record;
   R : Rec;
   package Inner is
      V : Integer := 5;
   end Inner;
   procedure Q01 (N : Integer; Sink : out Integer);
   procedure Q02 (N : Integer; Sink : out Integer);
   procedure Q03 (N : Integer; Sink : out Integer);
   procedure Q04 (N : Integer; Sink : out Integer);
   procedure Q05 (N : Integer; Sink : out Integer);
   procedure Q06 (N : Integer; Sink : out Integer);
end H12;

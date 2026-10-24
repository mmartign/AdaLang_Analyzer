package body Verification_Subtype_Clamp
  with SPARK_Mode
is
   procedure Ok_Assigned (A : Integer; X : out Integer) is
      Y : Natural;
   begin
      Y := A;
      X := Y - 1;
   end Ok_Assigned;

   procedure Ok_Initial (A : Integer; X : out Integer) is
      Y : constant Positive := A;
   begin
      X := Y - 2;
   end Ok_Initial;

   procedure Ok_Constraint (A : Integer; X : out Integer) is
      Y : Integer range -1_000 .. 1_000 := 0;
   begin
      Y := A;
      X := Y * 1_000;
   end Ok_Constraint;

   procedure Ok_Named (A : Integer; X : out Integer) is
      Y : Small;
   begin
      Y := A;
      X := Y * 3;
   end Ok_Named;

   procedure Ok_Loop (Limit : Natural; X : out Integer) is
      Count : Natural := 0;
   begin
      while Count < Limit loop
         Count := Count + 1;
      end loop;
      X := Count - 4;
   end Ok_Loop;

   --  Y can be Natural'Last.
   procedure Bad_Top (A : Integer; X : out Integer) is
      Y : Natural;
   begin
      Y := A;
      X := Y + 1;
   end Bad_Top;

   --  What is stored through R is checked against the subtype of Y, not
   --  against the Natural the renaming names: R can be -1.
   procedure Bad_Renaming (A : Integer; X : out Integer) is
      Y : Integer := 0;
      R : Natural renames Y;
   begin
      R := A;
      X := 10 / (R + 1);
   end Bad_Renaming;

   --  Upto is 0 .. 10, the value N had when it was elaborated, and Y can
   --  be 6 after N is 5.
   procedure Bad_Moved_Bound (A : Integer; X : out Integer)
     with SPARK_Mode => Off
   is
      N : Integer := 10;
      subtype Upto is Integer range 0 .. N;
      Y : Upto := 0;
   begin
      N := 5;
      Y := A;
      X := 10 / (6 - Y);
   end Bad_Moved_Bound;
end Verification_Subtype_Clamp;

--  X'Old in postconditions: in the postcondition of the subprogram being
--  verified, the value X had on entry; in the postcondition of a callee,
--  the value the actual had when the call was made. The postconditions and
--  assertions of the subprograms named Ok_* hold, those of the ones named
--  Bad_* do not: two increments are not one (Bad_Two), a parameter that
--  is not written keeps its value (Bad_Kept), a callee that changes a
--  component (Bad_Component), and two that are not known: after a call
--  of unknown effects (Bad_Unknown) and after a loop (Bad_Loop), what the
--  names of the entry state stand for is not known any more. GNATprove
--  proves the checks of the Ok_* subprograms and none of the checks of the
--  Bad_* ones.
package Verification_Old with SPARK_Mode is

   procedure Inc (Y : in out Integer)
     with Pre => Y < Integer'Last, Post => Y = Y'Old + 1;

   procedure Ok_Two (Two_X : in out Integer)
     with Pre => Two_X < Integer'Last - 1, Post => Two_X = Two_X'Old + 2;

   procedure Bad_Two (Bad_X : in out Integer)
     with Pre => Bad_X < Integer'Last - 1, Post => Bad_X = Bad_X'Old + 1;

   procedure Unknown (X : in out Integer)
     with Global => null, Import, Convention => C;

   procedure Bad_Unknown (Unknown_X : in out Integer)
     with Pre => Unknown_X < Integer'Last - 1,
          Post => Unknown_X = Unknown_X'Old + 1;

   procedure Bad_Loop (Loop_X : in out Integer; N : Natural)
     with Pre => Loop_X < 0, Post => Loop_X = Loop_X'Old;

   procedure Ok_Kept (Kept_X : in out Integer; Y : Integer)
     with Post => Kept_X = Kept_X'Old + Y - Y;

   procedure Bad_Kept (Moved_X : in out Integer)
     with Post => Moved_X = Moved_X'Old + 1;

   procedure Ok_In (In_X : Integer; Z : out Integer)
     with Post => Z = In_X'Old;

   type Inner is private;

   function Rate_Of (C : Inner) return Positive
     with Global => null;

   procedure Step (C : in out Inner)
     with Post => Rate_Of (C) = Rate_Of (C'Old);

   procedure Bump (C : in out Inner)
     with Post => Rate_Of (C) /= Rate_Of (C'Old);

   type Byte_Array is array (Positive range <>) of Natural;
   subtype Bytes is Byte_Array (1 .. 8);

   procedure Step_With
     (C : in out Inner; Data : Bytes; Out_Data : out Byte_Array)
     with Post => Rate_Of (C) = Rate_Of (C'Old);

   type Outer is record
      I    : Inner;
      Len  : Natural;
      Data : Bytes;
      Key  : Bytes;
   end record;

   Width : constant Positive := 4;

   procedure Ok_Component (Ok_O : in out Outer)
     with Post => Rate_Of (Ok_O.I) = Rate_Of (Ok_O.I'Old);

   procedure Bad_Component (Bad_O : in out Outer)
     with Post => Rate_Of (Bad_O.I) = Rate_Of (Bad_O.I'Old);

   procedure Ok_Assert (Assert_O : in out Outer);

   --  One call is given two components of one record, and a slice of a
   --  third whose bounds name a constant.
   procedure Ok_Parts (Parts_O : in out Outer)
     with Post => Rate_Of (Parts_O.I) = Rate_Of (Parts_O.I'Old)
                  and then Parts_O.Len = Parts_O.Len'Old;

private
   type Inner is record
      Rate : Positive;
   end record;

   function Rate_Of (C : Inner) return Positive is (C.Rate);
end Verification_Old;

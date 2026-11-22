--  Uninitialized_Read: the same shape as the clean sibling, a call that is
--  an actual of another call with an out actual, but the out actual is
--  another object: Status is still read before it has a value, which must
--  be reported (FP-171).

procedure Precision_Uninitialized_Read_Inner_Call_Other_Finding
  (Command : String; Code : out Integer)
is
   function Run (C : String; Status : out Integer) return Natural is
   begin
      Status := C'Length;
      return 1;
   end Run;
   function Twice (N : Natural) return Natural is (2 * N);

   Status : Integer;
   Other  : Integer;
   R      : Natural;
begin
   R := Twice (Run (Command, Other));
   Code := Status + Other + R;
end Precision_Uninitialized_Read_Inner_Call_Other_Finding;

--  Precision regression for Depends_Contract_Mismatch (FP-126, FP-127,
--  FP-128): Depends aspects that hold, and that GNATprove proves. A state
--  abstraction named by an expanded name is an output and an input like
--  any object (FP-126). An out parameter of an indefinite type brings in
--  its bounds, so "D =>+ V" is legal and holds (FP-127). A function that
--  reads an object named in its Global aspect gives a value that depends
--  on that object (FP-128).
procedure Depends_States_And_Bounds_Clean with SPARK_Mode is

   type Arr is array (Positive range <>) of Integer;

   package Log
     with Abstract_State => State, Initializes => State
   is
      procedure Add (X : Integer)
        with Global => (In_Out => State), Depends => (State =>+ X);
   end Log;

   package body Log
     with Refined_State => (State => Count)
   is
      Count : Integer := 0;

      procedure Add (X : Integer)
        with Refined_Global  => (In_Out => Count),
             Refined_Depends => (Count =>+ X)
      is
      begin
         if X > 0 and then Count < Integer'Last - X then
            Count := Count + X;
         end if;
      end Add;
   end Log;

   procedure Note (A : Integer; Y : out Integer)
     with Global  => (In_Out => Log.State),
          Depends => (Log.State =>+ A, Y => A)
   is
   begin
      Log.Add (A);
      Y := A;
   end Note;

   procedure Fill (D : out Arr; V : Integer)
     with Global => null, Depends => (D =>+ V)
   is
   begin
      for I in D'Range loop
         D (I) := V;
      end loop;
   end Fill;

   procedure Describe (X : Integer; D : out Integer)
     with Global => null, Depends => (D => X)
   is
      T : constant Integer := X;
      function Get return Integer is (T)
        with Global => T;
   begin
      D := Get;
   end Describe;

   Y : Integer;
   D : Arr (1 .. 3);
begin
   Note (1, Y);
   Fill (D, Y);
   Describe (Y, Y);
end Depends_States_And_Bounds_Clean;

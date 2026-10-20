--  The flow-dependencies obligation: each output depends on what the
--  Depends aspect lists for it and on nothing else. The aspects of the
--  subprograms named Ok_* hold; those of the subprograms named Bad_* do
--  not, each for one reason: a condition (Bad_Cond, Bad_Case), a return
--  taken under a condition (Bad_Return), the number of times a loop goes
--  round (Bad_Loop, Bad_For) or the condition it is left under (Bad_Exit,
--  Bad_Mid), a part of a record left as it was (Bad_Part), a callee's
--  contract (Bad_Call, Bad_Swap), a global (Bad_Bump, Bad_Nested,
--  Bad_Table), a function result (Bad_F), a constituent of a state
--  abstraction (Bad_State), the bounds of an array (Bad_Bounds, and
--  Bad_Local_Bounds, where a callee reads those of a local), and a
--  value kept in a state abstraction whose refinement the caller does not
--  see (Bad_View, Bad_Entry). Bad_Extra lists a flow that does not exist.
--  GNATprove (flow analysis) proves the aspects of the Ok_* subprograms and
--  reports a missing or an incorrect dependency for each of the Bad_*
--  subprograms but Bad_Formal: its generic is instantiated with a
--  procedure that writes a global, which GNATprove reports missing from
--  the Global aspect. Its effects are not known here.
package Verification_Flow_Dependencies
  with SPARK_Mode, Abstract_State => Hidden, Initializes => (G, Hidden)
is
   G : Integer := 0;

   type Arr is array (Positive range <>) of Integer;
   type Rec is record
      A, B : Integer;
   end record;

   Table    : constant Arr (1 .. 3) := (1, 2, 3);
   Deferred : constant Integer;

   procedure Ok_Plain (X : Integer; Y : out Integer)
     with Global => null, Depends => (Y => X);
   procedure Bad_Cond (C : Boolean; X : Integer; Y : out Integer)
     with Global => null, Depends => (Y => X, null => C);
   procedure Ok_Cond (C : Boolean; X : Integer; Y : out Integer)
     with Global => null, Depends => (Y => (C, X));
   procedure Bad_Return (C : Boolean; Y : out Integer)
     with Global => null, Depends => (Y => null, null => C);
   procedure Bad_Loop (N : Natural; Y : out Natural)
     with Global => null, Depends => (Y => null, null => N);
   procedure Ok_Loop (N : Natural; Y : out Natural)
     with Global => null, Depends => (Y => N);
   procedure Bad_Exit (A : Arr; Y : out Natural)
     with Global => null, Depends => (Y => null, null => A);
   procedure Ok_Exit (A : Arr; Y : out Natural)
     with Global => null, Depends => (Y => A);
   procedure Ok_Init (R : out Rec; X : Integer)
     with Global => null, Depends => (R => X);
   --  R.B is not written: what R holds on entry, an initialization error,
   --  is no input.
   procedure Ok_Part_Out (R : out Rec; X : Integer)
     with Global => null, Depends => (R => X);
   procedure Bad_Part (R : in out Rec; X : Integer)
     with Global => null, Depends => (R => X, null => R);
   procedure Ok_Part (R : in out Rec; X : Integer)
     with Global => null, Depends => (R =>+ X);
   procedure Ok_Call (A, B : Integer; Z : out Integer)
     with Global => null, Depends => (Z => A, null => B);
   procedure Bad_Call (A, B : Integer; Z : out Integer)
     with Global => null, Depends => (Z => A, null => B);
   procedure Ok_Set (X : Integer)
     with Global => (Output => G), Depends => (G => X);
   procedure Bad_Bump
     with Global => (In_Out => G), Depends => (G => null, null => G);
   function Ok_F (X, Y : Integer) return Integer
     with Global => null, Depends => (Ok_F'Result => X, null => Y);
   function Bad_F (X, Y : Integer) return Integer
     with Global => null, Depends => (Bad_F'Result => X, null => Y);
   procedure Ok_Nested (X : Integer; Y : out Integer)
     with Global => null, Depends => (Y => X);
   procedure Bad_Nested (X : Integer; Y : out Integer)
     with Global => (Input => G), Depends => (Y => X, null => G);
   procedure Ok_Fill (D : out Arr)
     with Global => null, Depends => (D =>+ null);
   procedure Bad_Bounds (D : out Arr; Y : out Natural)
     with Global => null, Depends => (D =>+ null, Y => null);
   procedure Bad_Case (K : Natural; Y : out Integer)
     with Global => null, Depends => (Y => null, null => K);
   procedure Ok_State (X : Integer)
     with Global => (In_Out => Hidden), Depends => (Hidden =>+ X);
   procedure Bad_State (X : Integer; Y : out Integer)
     with Global => (Input => Hidden), Depends => (Y => X, null => Hidden);
   procedure Bad_For (N : Natural; Y : out Natural)
     with Global => null, Depends => (Y => null, null => N);
   procedure Bad_Mid (A : Arr; Y : out Integer)
     with Global => null, Depends => (Y => null, null => A);
   procedure Bad_Swap (A, B : in out Integer)
     with Global => null, Depends => (A => A, B => B);
   procedure Ok_Swap (A, B : in out Integer)
     with Global => null, Depends => (A => B, B => A);
   procedure Ok_Table (I : Positive; Y : out Integer)
     with Global => null, Depends => (Y => I);
   procedure Ok_Deferred (Y : out Integer)
     with Global => null, Depends => (Y => null);
   procedure Bad_Table (I : Positive; Y : out Integer)
     with Global => (Input => G), Depends => (Y => I, null => G);
   procedure Bad_Extra (A, B : Integer; Y : out Integer)
     with Global => null, Depends => (Y => (A, B));

   procedure Count (A : in out Arr; C : out Natural)
     with Global => null, Depends => (A => A, C => A);
   procedure Ok_Local_Bounds (N : Positive; Y : out Natural)
     with Global => null, Depends => (Y => N);
   procedure Bad_Local_Bounds (N : Positive; Y : out Natural)
     with Global => null, Depends => (Y => null, null => N);

   --  A state abstraction whose refinement the subprograms below do not see.
   package Store
     with Abstract_State => S, Initializes => S
   is
      procedure Set (X : Integer)
        with Global => (Output => S), Depends => (S => X);
      function Get return Integer
        with Global => S;
   end Store;

   procedure Bad_View (X : Integer; Y : out Integer)
     with Global => (Output => Store.S), Depends => (Store.S => X, Y => null);
   procedure Ok_View (X : Integer; Y : out Integer)
     with Global => (Output => Store.S), Depends => (Store.S => X, Y => X);
   procedure Bad_Entry (Y : out Integer)
     with Global => (Input => Store.S), Depends => (Y => null, null => Store.S);

   --  Every actual of Step touches nothing outside it in Clean_Twice, not in
   --  Dirty_Twice.
   generic
      with procedure Step (X : in out Integer);
   package Clean_Twice is
      procedure Ok_Formal (X : in out Integer)
        with Global => null, Depends => (X => X);
   end Clean_Twice;

   generic
      with procedure Step (X : in out Integer);
   package Dirty_Twice is
      procedure Bad_Formal (X : in out Integer)
        with Global => null, Depends => (X => X);
   end Dirty_Twice;

   procedure Increment (X : in out Integer)
     with Global => null, Depends => (X => X);
   procedure Increment_G (X : in out Integer)
     with Global => (In_Out => G), Depends => (X => X, G => X, null => G);

private
   Deferred : constant Integer := 7;
end Verification_Flow_Dependencies;

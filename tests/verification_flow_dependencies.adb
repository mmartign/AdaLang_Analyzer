package body Verification_Flow_Dependencies
  with SPARK_Mode, Refined_State => (Hidden => H)
is
   H : Integer := 0;

   procedure Swap (A, B : in out Integer)
     with Global => null, Depends => (A => B, B => A)
   is
      T : constant Integer := A;
   begin
      A := B;
      B := T;
   end Swap;

   procedure Callee (X : Integer; Y : out Integer)
     with Global => null, Depends => (Y => X)
   is
   begin
      Y := X;
   end Callee;

   procedure Ok_Plain (X : Integer; Y : out Integer) is
   begin
      if X < Integer'Last then
         Y := X + 1;
      else
         Y := X;
      end if;
   end Ok_Plain;

   procedure Bad_Cond (C : Boolean; X : Integer; Y : out Integer) is
   begin
      if C then
         Y := X;
      else
         Y := 0;
      end if;
   end Bad_Cond;

   procedure Ok_Cond (C : Boolean; X : Integer; Y : out Integer) is
   begin
      if C then
         Y := X;
      else
         Y := 0;
      end if;
   end Ok_Cond;

   procedure Bad_Return (C : Boolean; Y : out Integer) is
   begin
      Y := 1;
      if C then
         return;
      end if;
      Y := 2;
   end Bad_Return;

   procedure Bad_Loop (N : Natural; Y : out Natural) is
      K : Natural := N;
   begin
      Y := 0;
      while K > 0 loop
         pragma Loop_Variant (Decreases => K);
         K := K - 1;
         if Y < Natural'Last then
            Y := Y + 1;
         end if;
      end loop;
   end Bad_Loop;

   procedure Ok_Loop (N : Natural; Y : out Natural) is
      K : Natural := N;
   begin
      Y := 0;
      while K > 0 loop
         pragma Loop_Variant (Decreases => K);
         K := K - 1;
         if Y < Natural'Last then
            Y := Y + 1;
         end if;
      end loop;
   end Ok_Loop;

   procedure Bad_Exit (A : Arr; Y : out Natural) is
   begin
      Y := 0;
      for I in 1 .. 3 loop
         exit when I > A'Length or else A (A'First) = 0;
         Y := I;
      end loop;
   end Bad_Exit;

   procedure Ok_Exit (A : Arr; Y : out Natural) is
   begin
      Y := 0;
      for I in 1 .. 3 loop
         exit when I > A'Length or else A (A'First) = 0;
         Y := I;
      end loop;
   end Ok_Exit;

   procedure Ok_Init (R : out Rec; X : Integer) is
   begin
      R.A := X;
      R.B := 0;
   end Ok_Init;

   procedure Ok_Part_Out (R : out Rec; X : Integer) is
   begin
      R.A := X;
   end Ok_Part_Out;

   procedure Bad_Part (R : in out Rec; X : Integer) is
   begin
      R.A := X;
   end Bad_Part;

   procedure Ok_Part (R : in out Rec; X : Integer) is
   begin
      R.A := X;
   end Ok_Part;

   procedure Ok_Call (A, B : Integer; Z : out Integer) is
      pragma Unreferenced (B);
   begin
      Callee (A, Z);
   end Ok_Call;

   procedure Bad_Call (A, B : Integer; Z : out Integer) is
      pragma Unreferenced (A);
   begin
      Callee (B, Z);
   end Bad_Call;

   procedure Ok_Set (X : Integer) is
   begin
      G := X;
   end Ok_Set;

   procedure Bad_Bump is
   begin
      if G < Integer'Last then
         G := G + 1;
      end if;
   end Bad_Bump;

   function Ok_F (X, Y : Integer) return Integer is
      pragma Unreferenced (Y);
   begin
      return X;
   end Ok_F;

   function Bad_F (X, Y : Integer) return Integer is
   begin
      if Y > 0 then
         return X;
      end if;
      return 0;
   end Bad_F;

   procedure Ok_Nested (X : Integer; Y : out Integer) is
      procedure Inner is
      begin
         Y := X;
      end Inner;
   begin
      Inner;
   end Ok_Nested;

   procedure Bad_Nested (X : Integer; Y : out Integer) is
      procedure Inner is
      begin
         if G > 0 then
            Y := X;
         else
            Y := 0;
         end if;
      end Inner;
   begin
      Inner;
   end Bad_Nested;

   procedure Ok_Fill (D : out Arr) is
   begin
      for I in D'Range loop
         D (I) := 0;
      end loop;
   end Ok_Fill;

   procedure Bad_Bounds (D : out Arr; Y : out Natural) is
   begin
      for I in D'Range loop
         D (I) := 0;
      end loop;
      Y := D'Length;
   end Bad_Bounds;

   procedure Bad_Case (K : Natural; Y : out Integer) is
   begin
      case K is
         when 0 => Y := 1;
         when others => Y := 2;
      end case;
   end Bad_Case;

   procedure Ok_State (X : Integer)
     with Refined_Global => (In_Out => H), Refined_Depends => (H =>+ X)
   is
   begin
      if X > 0 and then H < Integer'Last - X then
         H := H + X;
      end if;
   end Ok_State;

   procedure Bad_State (X : Integer; Y : out Integer)
     with Refined_Global  => (Input => H),
          Refined_Depends => (Y => X, null => H)
   is
   begin
      if H > 0 then
         Y := X;
      else
         Y := 0;
      end if;
   end Bad_State;

   procedure Bad_For (N : Natural; Y : out Natural) is
   begin
      Y := 0;
      for I in 1 .. N loop
         Y := I;
      end loop;
   end Bad_For;

   procedure Bad_Mid (A : Arr; Y : out Integer) is
   begin
      Y := 0;
      for I in A'Range loop
         Y := 1;
         exit when A (I) = 0;
         Y := 2;
      end loop;
   end Bad_Mid;

   procedure Bad_Swap (A, B : in out Integer) is
   begin
      Swap (A, B);
   end Bad_Swap;

   procedure Ok_Swap (A, B : in out Integer) is
   begin
      Swap (A, B);
   end Ok_Swap;

   procedure Ok_Table (I : Positive; Y : out Integer) is
   begin
      if I in Table'Range then
         Y := Table (I);
      else
         Y := 0;
      end if;
   end Ok_Table;

   procedure Ok_Deferred (Y : out Integer) is
   begin
      Y := Deferred;
   end Ok_Deferred;

   procedure Bad_Table (I : Positive; Y : out Integer) is
   begin
      if I in Table'Range and then G in Table'Range then
         Y := Table (G);
      else
         Y := 0;
      end if;
   end Bad_Table;

   procedure Bad_Extra (A, B : Integer; Y : out Integer) is
      pragma Unreferenced (B);
   begin
      Y := A;
   end Bad_Extra;

   procedure Count (A : in out Arr; C : out Natural) is
   begin
      C := A'Length;
   end Count;

   procedure Ok_Local_Bounds (N : Positive; Y : out Natural) is
      L : Arr (1 .. N) := (others => 0);
   begin
      Count (L, Y);
   end Ok_Local_Bounds;

   procedure Bad_Local_Bounds (N : Positive; Y : out Natural) is
      L : Arr (1 .. N) := (others => 0);
   begin
      Count (L, Y);
   end Bad_Local_Bounds;

   package body Store
     with Refined_State => (S => V)
   is
      V : Integer := 0;

      procedure Set (X : Integer)
        with Refined_Global => (Output => V), Refined_Depends => (V => X)
      is
      begin
         V := X;
      end Set;

      function Get return Integer is (V)
        with Refined_Global => V;
   end Store;

   procedure Bad_View (X : Integer; Y : out Integer) is
   begin
      Store.Set (X);
      Y := Store.Get;
   end Bad_View;

   procedure Ok_View (X : Integer; Y : out Integer) is
   begin
      Store.Set (X);
      Y := Store.Get;
   end Ok_View;

   procedure Bad_Entry (Y : out Integer) is
   begin
      Y := Store.Get;
   end Bad_Entry;

   package body Clean_Twice is
      procedure Ok_Formal (X : in out Integer) is
      begin
         Step (X);
         Step (X);
      end Ok_Formal;
   end Clean_Twice;

   package body Dirty_Twice is
      procedure Bad_Formal (X : in out Integer) is
      begin
         Step (X);
         Step (X);
      end Bad_Formal;
   end Dirty_Twice;

   procedure Increment (X : in out Integer) is
   begin
      if X < Integer'Last then
         X := X + 1;
      end if;
   end Increment;

   procedure Increment_G (X : in out Integer) is
   begin
      if X < Integer'Last then
         X := X + 1;
      end if;
      G := X;
   end Increment_G;

   package Clean is new Clean_Twice (Increment);
   package Dirty is new Dirty_Twice (Increment_G);
end Verification_Flow_Dependencies;

package body H01 is
   procedure Zero_G is
   begin
      G := 0;
   end Zero_G;

   function Zero_G_Fn return Integer is
   begin
      G := 0;
      return 1;
   end Zero_G_Fn;

   procedure Clear (X : in out Integer) is
   begin
      X := 0;
   end Clear;

   procedure Clear_Rec (X : in out Rec) is
   begin
      X.A := 0;
   end Clear_Rec;

   procedure Set_Through (P : Int_Access) is
   begin
      P.all := 0;
   end Set_Through;

   procedure P_Rename (N : Integer; Sink : out Integer) is
      Y : Integer := 5;
      Z : Integer renames Y;
   begin
      Y := 5 + N - N;
      Z := 0;
      Sink := 10 / Y;                 --  BAD
   end P_Rename;

   procedure P_Overlay (N : Integer; Sink : out Integer) is
      W : Integer := 5;
      O : Integer with Address => W'Address, Import;
   begin
      W := 5;
      O := N - N;
      Sink := 10 / W;                 --  BAD
   end P_Overlay;

   procedure P_Global_Proc (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Zero_G;
      Sink := 10 / G + N;             --  BAD
   end P_Global_Proc;

   procedure P_Global_Fn (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := Zero_G_Fn + N;
      Sink := 10 / G;                 --  BAD
   end P_Global_Fn;

   procedure P_Global_Fn_Cond (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := N;
      if Zero_G_Fn = 1 then
         Sink := 10 / G;              --  BAD
      end if;
   end P_Global_Fn_Cond;

   procedure P_In_Out (N : Integer; Sink : out Integer) is
      Y : Integer := 5;
   begin
      Clear (Y);
      Sink := 10 / Y + N;             --  BAD
   end P_In_Out;

   procedure P_Rec_Assign (N : Integer; Sink : out Integer) is
      R : Rec;
      R2 : constant Rec := (A => N - N, B => 0);
   begin
      R.A := 5;
      R := R2;
      Sink := 10 / R.A;               --  BAD
   end P_Rec_Assign;

   procedure P_Rec_Call (N : Integer; Sink : out Integer) is
      R : Rec;
   begin
      R.A := 5;
      Clear_Rec (R);
      Sink := 10 / R.A + N;           --  BAD
   end P_Rec_Call;

   procedure P_Rec_Comp_Call (N : Integer; Sink : out Integer) is
      R : Rec;
   begin
      R.A := 5;
      Clear (R.A);
      Sink := 10 / R.A + N;           --  BAD
   end P_Rec_Comp_Call;

   procedure P_Arr_Dyn (N : Integer; Sink : out Integer) is
      A : Arr := (others => 5);
   begin
      A (1) := 5;
      if N in 1 .. 4 then
         A (N) := 0;
      end if;
      Sink := 10 / A (1);             --  BAD
   end P_Arr_Dyn;

   procedure P_Arr_Agg (N : Integer; Sink : out Integer) is
      A : Arr := (others => 5);
   begin
      A (2) := 5;
      A := (others => N - N);
      Sink := 10 / A (2);             --  BAD
   end P_Arr_Agg;

   procedure P_Arr_Call (N : Integer; Sink : out Integer) is
      A : Arr := (others => 5);
   begin
      A (3) := 5;
      Clear (A (3));
      Sink := 10 / A (3) + N;         --  BAD
   end P_Arr_Call;

   procedure P_Nested (N : Integer; Sink : out Integer) is
      Y : Integer := 5;
      procedure Inner is
      begin
         Y := 0;
      end Inner;
   begin
      Y := 5;
      Inner;
      Sink := 10 / Y + N;             --  BAD
   end P_Nested;

   procedure P_Nested_Fn (N : Integer; Sink : out Integer) is
      Y : Integer := 5;
      function Inner return Integer is
      begin
         Y := 0;
         return 1;
      end Inner;
   begin
      Y := 5;
      Sink := Inner + N;
      Sink := 10 / Y;                 --  BAD
   end P_Nested_Fn;

   procedure P_Volatile (N : Integer; Sink : out Integer) is
   begin
      Sink := N;
      if V /= 0 then
         Sink := 10 / V;              --  BAD
      end if;
      V := 5;
      Sink := 10 / V;                 --  BAD
   end P_Volatile;

   procedure P_Aliased_Global (N : Integer; Sink : out Integer) is
   begin
      Shared := 5;
      Set_Through (Shared_Ptr);
      Sink := 10 / Shared + N;        --  BAD
   end P_Aliased_Global;

   procedure P_Access_Attr (N : Integer; Sink : out Integer) is
      X : aliased Integer := 5;
   begin
      X := 5;
      Set_Through (X'Unchecked_Access);
      Sink := 10 / X + N;             --  BAD
   end P_Access_Attr;

   procedure P_Import (N : Integer; Sink : out Integer) is
      X : Integer := 5;
   begin
      Ext (X);
      Sink := 10 / X + N;             --  BAD
   end P_Import;

   procedure P_Import_Global (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Ext_No_Args;
      Sink := 10 / G + N;             --  BAD
   end P_Import_Global;

   procedure P_Import_Fn (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      Sink := Ext_Fn + N;
      Sink := 10 / G;                 --  BAD
   end P_Import_Fn;

   procedure P_Out_Alias (A : out Integer; B : in out Integer) is
   begin
      B := 5;
      A := 0;
      A := 10 / B;
   end P_Out_Alias;

   procedure P_Rec_Whole_In_Out (R : in out Rec; Sink : out Integer) is
   begin
      R.A := 5;
      R.B := 0;
      R := (A => R.B, B => R.A);
      Sink := 10 / R.A;               --  BAD
   end P_Rec_Whole_In_Out;

   procedure P_Nested_Rec (N : Integer; Sink : out Integer) is
      type Outer is record
         Inner : Rec;
      end record;
      O : Outer;
      Z : constant Rec := (A => N - N, B => 1);
   begin
      O.Inner.A := 5;
      O.Inner := Z;
      Sink := 10 / O.Inner.A;         --  BAD
   end P_Nested_Rec;

   procedure P_Slice (N : Integer; Sink : out Integer) is
      A : Arr := (others => 5);
   begin
      A (2) := 5;
      A (1 .. 3) := (others => N - N);
      Sink := 10 / A (2);             --  BAD
   end P_Slice;

   procedure P_Loop_Arr (N : Integer; Sink : out Integer) is
      A : Arr := (others => 5);
   begin
      A (4) := 5;
      for I in A'Range loop
         A (I) := N - N;
      end loop;
      Sink := 10 / A (4);             --  BAD
   end P_Loop_Arr;
end H01;

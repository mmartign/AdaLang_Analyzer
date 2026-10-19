package body Verification_Unknown_Effects with SPARK_Mode is

   type Int_Ptr is access Integer;
   Cell : Int_Ptr := new Integer'(0);

   procedure Touch (X : in out Integer) is
   begin
      Cell.all := X;
      X := 0;
   end Touch;

   procedure Set_Pos (X : in out Integer) is
   begin
      Cell.all := X;
      X := 1;
   end Set_Pos;

   procedure Set_Neg (X : in out Integer) is
   begin
      Cell.all := X;
      X := -1;
   end Set_Neg;

   procedure Act (Self : Root) is null;

   procedure Dispatch (X : Root'Class) with SPARK_Mode => Off is
   begin
      X.Act;
   end Dispatch;

   procedure Call_Back (P : not null access procedure)
     with SPARK_Mode => Off
   is
   begin
      P.all;
   end Call_Back;

   procedure Gen_Run with SPARK_Mode => Off is
   begin
      Action;
   end Gen_Run;

   procedure Part_Kept (R : in out Rec) is
      function Kept return Boolean is (R.B = 7);
   begin
      R.B := 7;
      Touch (R.A);
      pragma Assert (Kept);
   end Part_Kept;

   procedure Part_Given (R : in out Rec) is
      function Given return Boolean is (R.A = 7);
   begin
      R.A := 7;
      Touch (R.A);
      pragma Assert (Given);
   end Part_Given;

   procedure Local_Instance_Kept is
      L : Integer := 7;
      X : Integer := 1;
      procedure Clear is
      begin
         L := 0;
      end Clear;
      procedure Run is new Gen_Run (Clear);
   begin
      Touch (X);
      pragma Assert (L = 7);
      Run;
   end Local_Instance_Kept;

   procedure Local_Instance_Runs is
      L : Integer := 7;
      procedure Clear is
      begin
         L := 0;
      end Clear;
      procedure Run is new Gen_Run (Clear);
   begin
      Run;
      pragma Assert (L + 0 = 7);
   end Local_Instance_Runs;

   procedure Local_Dispatch is
      L : Integer := 7;
      type Child is new Root with null record;
      overriding procedure Act (Self : Child);
      procedure Act (Self : Child) is
      begin
         L := 0;
      end Act;
      C : Child;
   begin
      Dispatch (C);
      pragma Assert (L + 1 = 8);
   end Local_Dispatch;

   procedure Local_Access is
      L : Integer := 7;
      procedure Clear is
      begin
         L := 0;
      end Clear;
   begin
      Call_Back (Clear'Access);
      pragma Assert (L + 2 = 9);
   end Local_Access;

   procedure Needs_Deep (X : Integer) is null;

   procedure Deep_Right (X : Integer) is
   begin
      if L2 (X) > 0 then
         Needs_Deep (X);
      end if;
   end Deep_Right;

   procedure Deep_Wrong (X : Integer) is
   begin
      if L2 (X) > -1 then
         Needs_Deep (X);
      end if;
   end Deep_Wrong;

   procedure Needs_Ok (R : Rec) is null;

   procedure Join_Right (R : in out Rec; C : Boolean) is
   begin
      if C then
         Upd (R);
      end if;
      pragma Assert (R.A > 0);
   end Join_Right;

   procedure Join_Wrong (R : in out Rec; C : Boolean) is
   begin
      if C then
         Upd_Wrong (R);
      end if;
      pragma Assert (R.A + 0 > 0);
   end Join_Wrong;

   procedure Loop_Join_Right (R : in out Rec; C : Boolean; N : Natural) is
   begin
      for K in 1 .. N loop
         pragma Loop_Invariant (Ok (R));
         if C then
            exit when K > 5;
            Upd (R);
         end if;
         exit when K > 6;
         Needs_Ok (R);
      end loop;
   end Loop_Join_Right;

   procedure Loop_Join_Wrong (R : in out Rec; C : Boolean; N : Natural) is
   begin
      for K in 1 .. N loop
         pragma Loop_Invariant (Ok (R));
         if C then
            exit when K > 5;
            Upd_Wrong (R);
         end if;
         exit when K > 6;
         Needs_Ok (R);
         Upd (R);
      end loop;
   end Loop_Join_Wrong;

   procedure Upd (R : in out Rec) is
   begin
      Cell.all := R.B;
      R.A := 1;
   end Upd;

   procedure Upd_Wrong (R : in out Rec) is
   begin
      Cell.all := R.B;
      R.A := 0;
   end Upd_Wrong;

end Verification_Unknown_Effects;

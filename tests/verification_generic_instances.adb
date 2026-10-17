package body Verification_Generic_Instances is

   function Count (X : Integer) return Integer is
   begin
      Calls := Calls + 1;
      return X;
   end Count;

   procedure Run is
   begin
      Action;
   end Run;

   procedure Apply (X : in out Integer) is
   begin
      Action (X);
   end Apply;

   procedure Set (X : out Integer) is
   begin
      X := Value;
   end Set;

   procedure Inc is
   begin
      V := V + 1;
   end Inc;

   procedure Formal_Procedure is
      Counter : Integer := 0;
      procedure Bump is
      begin
         Counter := Counter + 1;
      end Bump;
      procedure Run_Bump is new Run (Bump);
   begin
      Run_Bump;
      pragma Assert (Counter = 0);
   end Formal_Procedure;

   procedure Formal_Procedure_Parameter is
      Other : Integer := 0;
      Y     : Integer := 5;
      procedure Touch (V : in out Integer) is
      begin
         Other := 1;
         V := V + 1;
      end Touch;
      procedure Apply_Touch is new Apply (Touch);
   begin
      Apply_Touch (Y);
      pragma Assert (Other = 0);
   end Formal_Procedure_Parameter;

   procedure Formal_Object_Copied is
      Local : Integer := 5;
      procedure Set_Local is new Set (Local);
      A : Integer;
   begin
      Local := 7;
      Set_Local (A);
      pragma Assert (A = 7);
   end Formal_Object_Copied;

   procedure Formal_Object_Renamed is
      Local : Integer := 0;
      procedure Inc_Local is new Inc (Local);
   begin
      Local := 0;
      Inc_Local;
      pragma Assert (Local = 0);
   end Formal_Object_Renamed;

   procedure Two_Instances is
      procedure Set_One is new Set (1);
      procedure Set_Two is new Set (2);
      A, B : Integer;
   begin
      Set_One (A);
      Set_Two (B);
      pragma Assert (A = B);
   end Two_Instances;

   procedure Actual_Evaluated is
   begin
      Calls := 0;
      declare
         procedure Set_Counted is new Set (Count (3));
      begin
         pragma Assert (Calls = 0);
      end;
   end Actual_Evaluated;

   procedure Before_The_Call (X : Integer) is
      Counter : Integer := 0;
      procedure Bump is
      begin
         Counter := Counter + 1;
      end Bump;
      procedure Run_Bump is new Run (Bump);
   begin
      pragma Assert (X > 0);
      Run_Bump;
   end Before_The_Call;

end Verification_Generic_Instances;

--  A call whose effects are not known -- a write through an access value
--  in the callee -- leaves what is known of the objects the caller does
--  not give it, in SPARK code that keeps its objects to itself: one that
--  declares functions, procedures and instances of generic procedures of
--  its own and takes no access value or address of anything. It does not
--  where a local instance runs a local procedure (Local_Instance_Runs),
--  where a local tagged type's primitive is reached by dispatching
--  (Local_Dispatch), or where a local procedure is handed out by 'Access
--  (Local_Access). An expression function is read eight bodies deep, and
--  where two paths meet, what each states alike of the values it gives a
--  part stands. Each assertion and precondition of Part_Given,
--  Local_Instance_Runs, Local_Dispatch, Local_Access, Deep_Wrong,
--  Join_Wrong and Loop_Join_Wrong fails at run time. The others hold.
package Verification_Unknown_Effects with SPARK_Mode is

   type Rec is record
      A : Integer;
      B : Integer;
   end record;

   procedure Touch (X : in out Integer);
   procedure Set_Pos (X : in out Integer) with Post => X > 0;
   procedure Set_Neg (X : in out Integer) with Post => X < 0;

   type Root is tagged null record;
   procedure Act (Self : Root);
   procedure Dispatch (X : Root'Class);

   procedure Call_Back (P : not null access procedure);

   generic
      with procedure Action;
   procedure Gen_Run;

   procedure Part_Kept (R : in out Rec);
   procedure Part_Given (R : in out Rec);
   procedure Local_Instance_Kept;
   procedure Local_Instance_Runs;
   procedure Local_Dispatch;
   procedure Local_Access;

   function L5 (X : Integer) return Integer is (X);
   function L4 (X : Integer) return Integer is (L5 (X));
   function L3 (X : Integer) return Integer is (L4 (X));
   function L2 (X : Integer) return Integer is (L3 (X));
   function L1 (X : Integer) return Integer is (L2 (X));
   function Deep_Positive (X : Integer) return Boolean is (L1 (X) > 0);

   procedure Needs_Deep (X : Integer) with Pre => Deep_Positive (X);
   procedure Deep_Right (X : Integer);
   procedure Deep_Wrong (X : Integer);

   function Ok (R : Rec) return Boolean is (R.A > 0);
   procedure Upd (R : in out Rec) with Post => Ok (R);
   procedure Upd_Wrong (R : in out Rec) with Post => R.A = 0;
   procedure Needs_Ok (R : Rec) with Pre => Ok (R);

   procedure Join_Right (R : in out Rec; C : Boolean) with Pre => R.A > 0;
   procedure Join_Wrong (R : in out Rec; C : Boolean) with Pre => R.A > 0;

   procedure Loop_Join_Right (R : in out Rec; C : Boolean; N : Natural)
     with Pre => Ok (R);
   procedure Loop_Join_Wrong (R : in out Rec; C : Boolean; N : Natural)
     with Pre => Ok (R);

end Verification_Unknown_Effects;

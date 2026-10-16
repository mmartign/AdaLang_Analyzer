package body Verification_FP121_Aliased_Parameter is

   procedure Set_Shared is
   begin
      Shared.C := 2;
   end Set_Shared;

   procedure Through_Pointer (V : aliased in out Integer) is
      Seen : Integer;
   begin
      Ptr.C := 2;
      Seen := V;
      pragma Assert (Seen = 1);
   end Through_Pointer;

   procedure Through_Call (V : aliased in out Integer) is
      Read : Integer;
   begin
      Set_Shared;
      Read := V;
      pragma Assert (Read = 1);
   end Through_Call;

   procedure By_Copy (V : in out Integer) is
      Kept : Integer;
   begin
      Ptr.C := 2;
      Kept := V;
      pragma Assert (Kept = 1);
   end By_Copy;

end Verification_FP121_Aliased_Parameter;

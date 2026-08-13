procedure Verification_VC_Call_Inlined (X_In : Integer) is
   function Double (Value : Integer) return Integer is (Value + Value);
   type Rec is record
      Age : Integer;
   end record;
   function Get_Age (The_Admin : Rec) return Integer is (The_Admin.Age);
   X : Integer := X_In;
   A : Rec := (Age => X_In);
begin
   pragma Assume (X >= 0 and then X <= 100);
   pragma Assert (Double (X) >= 0);
   if Get_Age (A) > 0 then
      pragma Assert (A.Age > 0);
   end if;
end Verification_VC_Call_Inlined;

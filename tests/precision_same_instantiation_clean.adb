procedure Precision_Same_Instantiation_Clean is
   generic
      type T is private;
      X : Integer;
   package Gen is
      Value : Integer := X;
   end Gen;

   generic
   package Empty is
   end Empty;

   package Inst_A is new Gen (Integer, 1);
   package Inst_B is new Gen (Integer, 2);
   package Inst_C is new Gen (Boolean, 1);
   package Empty_1 is new Empty;
   package Empty_2 is new Empty;
begin
   Inst_A.Value := Inst_B.Value + Inst_C.Value;
end Precision_Same_Instantiation_Clean;

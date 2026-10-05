with Precision_Same_Gen;
procedure Precision_Same_Inst2 is
   package Inst_3 is new Precision_Same_Gen (Integer, 2);
   package Inst_4 is new Precision_Same_Gen (X => 7, T => Boolean);
   package Inst_5 is new Precision_Same_Gen (Boolean, 7);
begin
   Inst_3.Value := Inst_4.Value + Inst_5.Value;
end Precision_Same_Inst2;

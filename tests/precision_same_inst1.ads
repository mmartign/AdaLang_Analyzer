with Precision_Same_Gen;
package Precision_Same_Inst1 is
   package Inst_1 is new Precision_Same_Gen (Integer, 2);
   package Inst_2 is new Precision_Same_Gen (Integer, 3);
end Precision_Same_Inst1;

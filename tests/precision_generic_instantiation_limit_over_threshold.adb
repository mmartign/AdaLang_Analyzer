procedure Precision_Generic_Instantiation_Limit_Over_Threshold is

   generic
      type T is private;
   package Gen is
      procedure Nop (X : T);
   end Gen;

   package body Gen is
      procedure Nop (X : T) is null;
   end Gen;

   package Inst_01 is new Gen (Integer);
   package Inst_02 is new Gen (Integer);
   package Inst_03 is new Gen (Integer);
   package Inst_04 is new Gen (Integer);
   package Inst_05 is new Gen (Integer);
   package Inst_06 is new Gen (Integer);
   package Inst_07 is new Gen (Integer);
   package Inst_08 is new Gen (Integer);
   package Inst_09 is new Gen (Integer);
   package Inst_10 is new Gen (Integer);
   package Inst_11 is new Gen (Integer);

begin
   null;
end Precision_Generic_Instantiation_Limit_Over_Threshold;

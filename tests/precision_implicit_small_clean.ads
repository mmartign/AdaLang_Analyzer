package Precision_Implicit_Small_Clean is
   type Money is delta 0.01 range 0.0 .. 1000.0 with Small => 0.01;
   type Price is delta 0.01 digits 8;
end Precision_Implicit_Small_Clean;

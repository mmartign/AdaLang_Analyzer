package Precision_Abstract_Type_Declaration_Clean is
   type Shape is tagged null record;
   function Area (S : Shape) return Float is (0.0);
end Precision_Abstract_Type_Declaration_Clean;

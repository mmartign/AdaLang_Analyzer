with Imported_Generics_Small;
package Imported_Generics_Ops with SPARK_Mode is
   Counter : Integer := 0;
   function "<" (L, R : Imported_Generics_Small.Small) return Boolean
     with Global => Counter;
end Imported_Generics_Ops;

package body Imported_Generics_Ops with SPARK_Mode is
   function "<" (L, R : Imported_Generics_Small.Small) return Boolean is
   begin
      return Integer (L) + Integer (R) < Counter;
   end "<";
end Imported_Generics_Ops;

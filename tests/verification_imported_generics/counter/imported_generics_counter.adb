package body Imported_Generics_Counter with SPARK_Mode is
   function "<" (L, R : Item) return Boolean is
   begin
      return L.N < R.N + Counter;
   end "<";
end Imported_Generics_Counter;

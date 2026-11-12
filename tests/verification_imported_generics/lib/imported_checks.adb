package body Imported_Checks with SPARK_Mode is
   package body Order_Checks is
      procedure Irreflexive (X : T) is
      begin
         Param_Irreflexive (X);
      end Irreflexive;

      function Lt (X, Y : T) return Boolean is
      begin
         return X < Y;
      end Lt;
   end Order_Checks;
end Imported_Checks;

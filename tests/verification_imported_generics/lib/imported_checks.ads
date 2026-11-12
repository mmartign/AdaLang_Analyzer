--  As SPARK.Containers.Parameter_Checks: no Always_Terminates of its own.
package Imported_Checks with SPARK_Mode is
   generic
      type T is private;
      with function "<" (X, Y : T) return Boolean;
      with procedure Param_Irreflexive (X : T);
   package Order_Checks is
      procedure Irreflexive (X : T) with Global => null;
      function Lt (X, Y : T) return Boolean with Global => null;
   end Order_Checks;
end Imported_Checks;

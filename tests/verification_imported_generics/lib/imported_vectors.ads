--  As SPARK.Containers.Formal.Unbounded_Vectors: a nested generic with
--  Always_Terminates that instantiates Imported_Checks with its formals.
with Imported_Checks;
generic
   type Element is private;
package Imported_Vectors with SPARK_Mode is
   function Size return Natural is (0);

   generic
      with function "<" (X, Y : Element) return Boolean is <>;
      with procedure Lt_Irreflexive (X : Element) is null;
   package Generic_Sorting with SPARK_Mode, Always_Terminates is
      package Lt_Checks is new Imported_Checks.Order_Checks
        (T => Element, "<" => "<", Param_Irreflexive => Lt_Irreflexive);
      function Is_Sorted (X, Y : Element) return Boolean is (not (Y < X));
   end Generic_Sorting;
end Imported_Vectors;

--  As SPARK.Containers.Functional.Maps: Always_Terminates on the generic,
--  formal procedures with a null default. Is_Zero raises a finding
--  (Floating_Equality) when the file is analyzed, none when it is only
--  verified as the generic unit of an imported project.
generic
   type Key is private;
   with procedure Key_Reflexive (X : Key) is null;
   with procedure Key_Symmetric (X, Y : Key) is null;
package Imported_Maps with SPARK_Mode, Always_Terminates is
   function Has (X : Key) return Boolean is (True);
   function Is_Zero (F : Float) return Boolean is (F = 0.0);
end Imported_Maps;

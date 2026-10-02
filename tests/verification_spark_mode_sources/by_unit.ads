--  SPARK_Mode is set for the whole unit by a pragma written before it.
pragma SPARK_Mode (On);

package By_Unit is
   Unit_Level : Integer := 5;
   function Unit_Probe (X : Integer) return Integer;
end By_Unit;

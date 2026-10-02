--  Excluded from SPARK, so Unmarked_Probe may do anything.
pragma SPARK_Mode (Off);

package Unmarked is
   Unmarked_Level : Integer := 5;
   function Unmarked_Probe (X : Integer) return Integer;
end Unmarked;

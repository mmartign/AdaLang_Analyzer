--  No SPARK_Mode here: it comes from the project's configuration pragmas
--  (main.gpr, spark.adc). Project_Probe has no body to read and no Global
--  contract, so only that mode says it leaves Project_Level alone.
package By_Project is
   Project_Level : Integer := 5;
   function Project_Probe (X : Integer) return Integer;
end By_Project;

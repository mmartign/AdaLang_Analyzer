package body Spark_Dependency_Separate_Findings with SPARK_Mode is
   procedure Wrong_Copy (A, B : Integer; X : out Integer) is
   begin
      X := A;
   end Wrong_Copy;
end Spark_Dependency_Separate_Findings;

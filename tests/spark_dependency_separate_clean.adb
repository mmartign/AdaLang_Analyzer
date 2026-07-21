package body Spark_Dependency_Separate_Clean with SPARK_Mode is
   procedure Copy (A : Integer; X : out Integer) is
   begin
      X := A;
   end Copy;
end Spark_Dependency_Separate_Clean;

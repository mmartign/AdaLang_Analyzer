package Spark_Dependency_Separate_Findings with SPARK_Mode is
   procedure Wrong_Copy (A, B : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => B, null => A);
end Spark_Dependency_Separate_Findings;

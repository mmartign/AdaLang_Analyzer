package Spark_Dependency_Separate_Clean with SPARK_Mode is
   procedure Copy (A : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => A);
end Spark_Dependency_Separate_Clean;

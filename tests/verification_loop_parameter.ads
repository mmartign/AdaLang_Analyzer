package Verification_Loop_Parameter with SPARK_Mode => On is

   procedure Counted (X : out Integer)
     with Post => X = 16;

   procedure Counted_Down (Y : out Integer);

   procedure Empty_Range (N : Natural);

   procedure After_Last;

   procedure Bound_Changed (N : in out Natural; X : out Natural);

end Verification_Loop_Parameter;

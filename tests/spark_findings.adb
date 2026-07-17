--  Positive regression fixture for SPARK mode and contract-aware flow.
procedure Spark_Findings is

   procedure Disabled_Region
     with SPARK_Mode => Off
   is
   begin
      null;
   end Disabled_Region;

   procedure Guarded (X : Integer)
     with Pre  => X > 0,
          Post => X > 0,
          Global => null,
          Depends => null
   is
   begin
      if X <= 0 then
         null;
      end if;
   end Guarded;

   procedure Broken_Post (X : in out Integer)
     with Post => 10 / X > 0
   is
   begin
      X := 0;
   end Broken_Post;

   Value : Integer := 1;

begin
   Disabled_Region;
   Guarded (1);
   Broken_Post (Value);
end Spark_Findings;

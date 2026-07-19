--  Positive regression fixture for SPARK mode and contract-aware flow.
procedure Spark_Findings is

   procedure Disabled_Region
     with SPARK_Mode => Off,
          Post       => False
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

   procedure Requires_Positive (X : Integer)
     with Pre => X > 0
   is
   begin
      null;
   end Requires_Positive;

   procedure Violates_Post (X : out Integer)
     with Post => X > 0
   is
   begin
      X := 0;
   end Violates_Post;

   procedure Establishes_Zero (X : out Integer)
     with Post => X = 0
   is
   begin
      X := 0;
   end Establishes_Zero;

   Shared : Integer := 0;

   procedure Reads_Shared
     with Global => (Input => Shared)
   is
   begin
      null;
   end Reads_Shared;

   Value : Integer := 1;
   Result : Integer := 0;

begin
   Disabled_Region;
   Guarded (1);
   Broken_Post (Value);
   Value := 0;
   Requires_Positive (X => Value);
   Violates_Post (Value);
   Establishes_Zero (Value);
   Result := 10 / Value;
   Reads_Shared;
   Result := 10 / Shared;
end Spark_Findings;

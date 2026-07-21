--  Negative regression fixture for complete SPARK flow contracts.
procedure Spark_Readiness_Clean is
   Shared : Integer := 1;

   procedure Read_Shared
     with Global => (Input => Shared)
   is
   begin
      if Shared > 0 then
         null;
      end if;
   end Read_Shared;

   procedure Copy_Value (Input : Integer; Output : out Integer)
     with Global  => null,
          Depends => (Output => Input)
   is
   begin
      Output := Input;
   end Copy_Value;

   procedure Set_Both (Left, Right : out Integer)
     with Global  => null,
          Depends => (Left => null, Right => null)
   is
   begin
      Left := 1;
      Right := 2;
   end Set_Both;

   procedure Set_On_All_Paths
     (Flag : Boolean; Output : out Integer)
     with Global  => null,
          Depends => (Output => Flag)
   is
   begin
      if Flag then
         Output := 1;
      else
         Output := 2;
      end if;
   end Set_On_All_Paths;

   Value : Integer;
   Other : Integer;
begin
   Read_Shared;
   Copy_Value (1, Value);
   if Value = 0 then
      null;
   end if;
   Set_On_All_Paths (True, Value);
   if Value = 0 then
      null;
   end if;
   Set_Both (Value, Other);
   if Value = Other then
      null;
   end if;
end Spark_Readiness_Clean;

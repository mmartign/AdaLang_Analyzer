--  Positive regression fixture for SPARK Bronze/readiness diagnostics.
procedure Spark_Readiness_Findings is
   A : Integer := 1;
   B : Integer := 2;
   C : Integer := 3;

   procedure Missing_Global is
   begin
      if A > 0 then
         null;
      end if;
   end Missing_Global;

   procedure Bad_Global
     with Global  => (Input => B, Output => C),
          Depends => (C => B)
   is
   begin
      B := C;
   end Bad_Global;

   procedure Missing_Depends (X : out Integer)
     with Global => null
   is
   begin
      X := 1;
   end Missing_Depends;

   procedure Incomplete_Depends (X : out Integer)
     with Global  => null,
          Depends => null
   is
   begin
      X := 1;
   end Incomplete_Depends;

   procedure Incomplete_Multiple (Left, Right : out Integer)
     with Global  => null,
          Depends => (Left => null)
   is
   begin
      Left := 1;
      Right := 2;
   end Incomplete_Multiple;

   procedure Partial_Output (Flag : Boolean; X : out Integer)
     with Global  => null,
          Depends => (X => Flag)
   is
   begin
      if Flag then
         X := 1;
      end if;
   end Partial_Output;

   Value : Integer;
begin
   Missing_Global;
   Bad_Global;
   Missing_Depends (Value);
   Incomplete_Depends (Value);
   Incomplete_Multiple (Value, B);
   Partial_Output (True, Value);
end Spark_Readiness_Findings;

--  Negative regression fixture for inferred SPARK Depends relations.
procedure Spark_Dependency_Clean is

   Source : Integer := 1;
   Target : Integer := 0;
   Counter : Integer := 0;

   procedure Copy_Global
     with Global  => (Input => Source, Output => Target),
          Depends => (Target => Source)
   is
   begin
      Target := Source;
   end Copy_Global;

   procedure Add_Global (Amount : Integer)
     with Global  => (In_Out => Counter),
          Depends => (Counter =>+ Amount)
   is
   begin
      Counter := Counter + Amount;
   end Add_Global;

   procedure Combine (A, B : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => (A, B))
   is
   begin
      X := A + B;
   end Combine;

   procedure Controlled
     (Flag : Boolean; A : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => (Flag, A))
   is
   begin
      if Flag then
         X := A;
      else
         X := A + 1;
      end if;
   end Controlled;

   procedure Constant_Output (Unused : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => null, null => Unused)
   is
   begin
      X := 42;
   end Constant_Output;

   procedure Accumulate (A : Integer; X : in out Integer)
     with Global  => null,
          Depends => (X =>+ A)
   is
   begin
      X := X + A;
   end Accumulate;

   procedure Copy (A : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => A)
   is
   begin
      X := A;
   end Copy;

   procedure Copy_Through_Call (A : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => A)
   is
   begin
      Copy (A, X);
   end Copy_Through_Call;

   procedure Count_To (N : Natural; X : out Integer)
     with Global  => null,
          Depends => (X => N)
   is
   begin
      X := 0;
      while X < N loop
         X := X + 1;
      end loop;
   end Count_To;

   procedure Sum_To (N : Natural; X : out Integer)
     with Global  => null,
          Depends => (X => N)
   is
   begin
      X := 0;
      for I in 1 .. N loop
         X := X + I;
      end loop;
   end Sum_To;

   procedure Count_Until (Limit : Natural; X : out Integer)
     with Global  => null,
          Depends => (X => Limit)
   is
   begin
      X := 0;
      for I in 1 .. 10 loop
         exit when I > Limit;
         X := X + 1;
      end loop;
   end Count_Until;

   procedure Handler_Flow (A : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => A)
   is
   begin
      X := 0;
      raise Constraint_Error;
   exception
      when others =>
         X := A;
   end Handler_Flow;

   Value : Integer := 0;
begin
   Combine (1, 2, Value);
   Controlled (True, 1, Value);
   Constant_Output (1, Value);
   Accumulate (1, Value);
   Copy_Through_Call (1, Value);
   Count_To (3, Value);
   Sum_To (3, Value);
   Count_Until (3, Value);
   Handler_Flow (1, Value);
   Copy_Global;
   Add_Global (1);
end Spark_Dependency_Clean;

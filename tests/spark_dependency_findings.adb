--  Positive regression fixture for inferred SPARK Depends relations.
procedure Spark_Dependency_Findings is

   Source : Integer := 1;
   Target : Integer := 0;
   Proof  : Integer := 1;

   procedure Wrong_Global_Flow
     with Global  => (Input => Source, Output => Target),
          Depends => (Target => null, null => Source)
   is
   begin
      Target := Source;
   end Wrong_Global_Flow;

   procedure Proof_Flow (X : out Integer)
     with Global  => (Proof_In => Proof),
          Depends => (X => Proof)
   is
   begin
      X := Proof;
   end Proof_Flow;

   procedure Missing_Data
     (A, B : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => A, null => B)
   is
   begin
      X := A + B;
   end Missing_Data;

   procedure Extra_Data
     (A, B : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => (A, B))
   is
   begin
      X := A;
   end Extra_Data;

   procedure Bad_Null (A : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => null, null => A)
   is
   begin
      X := A;
   end Bad_Null;

   procedure Missing_Control
     (Flag : Boolean; A : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => A, null => Flag)
   is
   begin
      if Flag then
         X := A;
      else
         X := A + 1;
      end if;
   end Missing_Control;

   procedure Missing_Self (A : Integer; X : in out Integer)
     with Global  => null,
          Depends => (X => A)
   is
   begin
      X := X + A;
   end Missing_Self;

   procedure Missing_Unused_Input
     (A, B : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => A)
   is
   begin
      X := A;
   end Missing_Unused_Input;

   procedure Copy (A : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => A)
   is
   begin
      X := A;
   end Copy;

   procedure Wrong_Call_Summary
     (A, B : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => B, null => A)
   is
   begin
      Copy (A, X);
   end Wrong_Call_Summary;

   procedure Missing_Loop_Control (N : Natural; X : out Integer)
     with Global  => null,
          Depends => (X => null, null => N)
   is
   begin
      X := 0;
      while X < N loop
         X := X + 1;
      end loop;
   end Missing_Loop_Control;

   procedure Missing_Exit_Control (Limit : Natural; X : out Integer)
     with Global  => null,
          Depends => (X => null, null => Limit)
   is
   begin
      X := 0;
      for I in 1 .. 10 loop
         exit when I > Limit;
         X := X + 1;
      end loop;
   end Missing_Exit_Control;

   procedure Missing_Handler_Flow (A : Integer; X : out Integer)
     with Global  => null,
          Depends => (X => null, null => A)
   is
   begin
      X := 0;
      raise Constraint_Error;
   exception
      when others =>
         X := A;
   end Missing_Handler_Flow;

   Value : Integer := 0;
begin
   Missing_Data (1, 2, Value);
   Extra_Data (1, 2, Value);
   Bad_Null (1, Value);
   Missing_Control (True, 1, Value);
   Missing_Self (1, Value);
   Missing_Unused_Input (1, 2, Value);
   Wrong_Call_Summary (1, 2, Value);
   Missing_Loop_Control (3, Value);
   Missing_Exit_Control (3, Value);
   Missing_Handler_Flow (1, Value);
   Wrong_Global_Flow;
   Proof_Flow (Value);
end Spark_Dependency_Findings;

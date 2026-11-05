package body Verification_Mutation_Loop_Entry_Records with SPARK_Mode is
   function Get (Ctx : Context; F : Field) return Integer is
     (Ctx.Cursors (F).Last);
   function Pos (A : Integer) return Integer is (A);

   procedure E1 (A : in out Integer; N : Natural) is
      X : Integer := 0;
   begin
      A := 0;
      for I in 1 .. N loop
         A := 1;
         X := Pos (A)'Loop_Entry;
      end loop;
   end E1;

   procedure E2 (Ctx : in out Context) is
      X : Integer := 0;
   begin
      for F in reverse Field loop
         Ctx.Cursors (F) := (State => S_Invalid, others => <>);
         X := Get (Ctx, F_A);
      end loop;
   end E2;

   procedure E3 (L : Late; Ok : out Boolean) is
   begin
      pragma Assert (L >= F_B);
      pragma Assert (L > F_B);
      Ok := True;
   end E3;

   procedure E4 (Ctx : in out Context; N : Natural) is
      X : Integer := 0;
   begin
      for I in 1 .. N loop
         pragma Loop_Invariant (Valid (Ctx.Cursors'Loop_Entry (F_B)));
         X := Get (Ctx, F_B);
         Ctx.Cursors (F_B) := (State => S_Invalid, others => <>);
      end loop;
   end E4;
end Verification_Mutation_Loop_Entry_Records;

package body Verification_Mutation_Array_Values with SPARK_Mode is
   --  An empty left operand: the result starts where Text does, 5.
   procedure Empty_Left (Text : String) is
      S : constant String := "" & Text;
   begin
      pragma Assert (S'First = 1);
   end Empty_Left;

   --  The left operand is a formal, which may start anywhere.
   procedure Formal_Left (Text : String) is
      T : constant String := Text & "!";
   begin
      pragma Assert (T'First = 1);
   end Formal_Left;

   --  A slice whose bound is a variable: its length is not 3 for every I.
   procedure Variable_Bound (N : Bytes_24; I : Index) is
      H : constant Bytes := N (I .. 3);
   begin
      pragma Assert (H'Length = 3);
   end Variable_Bound;

   --  A slice keeps its bounds: it does not slide to 0.
   procedure Slice_First (N : Bytes_24) is
      H : constant Bytes := N (2 .. 9);
   begin
      pragma Assert (H'First = 0);
   end Slice_First;
end Verification_Mutation_Array_Values;

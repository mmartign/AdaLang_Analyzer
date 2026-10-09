package body Verification_Mutation_Array_Bounds with SPARK_Mode => On is

   procedure Log (Text : String) is
   begin
      null;
   end Log;

   function Any return String is
   begin
      return "any";
   end Any;

   --  A slice has the bounds it is given: 2, here.
   procedure From_Slice (Whole : String) is
   begin
      Log (Whole (2 .. 5));
   end From_Slice;

   --  An object declared from 5 starts at 5.
   procedure From_Shifted (Moved : Shifted) is
   begin
      Log (Moved);
   end From_Shifted;

   --  The result of a function of an unconstrained subtype has bounds
   --  nothing fixes.
   procedure From_Unknown is
      Got : constant String := Any;
   begin
      Log (Got);
   end From_Unknown;

   --  Nor does anything fix those of a formal of such a subtype.
   procedure From_Formal (Passed : String) is
   begin
      Log (Passed);
   end From_Formal;

   --  The last bound may be Integer'Last.
   procedure Past_Last (Data : Bytes; R : out Integer) is
   begin
      if Data'First <= Data'Last then
         R := Data'Last + 1;
      else
         R := 0;
      end if;
   end Past_Last;

   --  The bounds of a null array are values of Integer, not of Natural.
   procedure Null_First (Data : Bytes) is
   begin
      pragma Assert (Data'First >= 0);
   end Null_First;

   --  Up to 2000, which is outside what the language guarantees of the
   --  base range of Wide and may well be inside what the compiler chose:
   --  not known to be safe, and not known to fail.
   procedure Sum (Left, Right : Wide; R : out Integer) is
   begin
      R := Integer (Left + Right);
   end Sum;

end Verification_Mutation_Array_Bounds;

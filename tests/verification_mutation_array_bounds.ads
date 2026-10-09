--  What is not known of the bounds of an array, nor of a base range the
--  compiler chooses. Each claim marked in the body is false, or rests on
--  nothing the analysis may rely on: none of them is to be proved, and
--  none that is not certainly wrong is to be called an error.
package Verification_Mutation_Array_Bounds with SPARK_Mode => On is

   type Bytes is array (Natural range <>) of Integer;

   subtype Shifted is String (5 .. 10);

   type Wide is range -1_000 .. 1_000;

   procedure Log (Text : String) with Pre => Text'First = 1;

   function Any return String;

   procedure From_Slice (Whole : String)
     with Pre => Whole'First = 1 and then Whole'Last >= 5;
   procedure From_Shifted (Moved : Shifted);
   procedure From_Unknown;
   procedure From_Formal (Passed : String);
   procedure Past_Last (Data : Bytes; R : out Integer);
   procedure Null_First (Data : Bytes);
   procedure Sum (Left, Right : Wide; R : out Integer);

end Verification_Mutation_Array_Bounds;

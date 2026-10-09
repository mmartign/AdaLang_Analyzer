package body Verification_Array_Bounds with SPARK_Mode => On is

   procedure Log (Text : String) is
   begin
      null;
   end Log;

   function Made return Line is (Blank);

   procedure From_Constant is
   begin
      Log (Blank);
   end From_Constant;

   procedure From_Literal is
   begin
      Log ("a string literal starts at Positive'First");
   end From_Literal;

   procedure From_Local is
      Kept : constant Line := Blank;
   begin
      Log (Kept);
   end From_Local;

   procedure From_Result is
   begin
      Log (Made);
   end From_Result;

   procedure From_Conversion (Other : String) is
   begin
      Log (Line (Other));
   end From_Conversion;

   --  Neither bound of an array that is not null is below Natural'First
   --  or above Integer'Last: their difference is a value of Integer.
   procedure Span (Data : Bytes; R : out Integer) is
   begin
      if Data'First <= Data'Last then
         R := Data'Last - Data'First;
      else
         R := 0;
      end if;
   end Span;

   --  At most 800: within -1000 .. 1000, which the base range of Wide
   --  includes whatever it is.
   procedure Sum (Left, Right : Half; R : out Wide) is
   begin
      R := Left + Right;
   end Sum;

end Verification_Array_Bounds;

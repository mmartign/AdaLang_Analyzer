package body Verification_Mutation_Literal_Bounds with SPARK_Mode is

   procedure Take_Short (X : Short_Text) is null;
   procedure Log (Description : String) is null;
   procedure Log_Three (Description : String) is null;
   procedure Need_Line (S : String) is null;

   procedure Too_Long is
   begin
      Take_Short ("abcdefg");
   end Too_Long;

   procedure Object_First (S : String) is
   begin
      Log (S & "abc");
   end Object_First;

   procedure Null_First (S : String) is
   begin
      Log ("" & S);
   end Null_First;

   procedure Wrong_Length is
   begin
      Log_Three ("ab" & "cd");
   end Wrong_Length;

   procedure Other_Bounds (M : Message) is
   begin
      Need_Line (M.Data);
   end Other_Bounds;

end Verification_Mutation_Literal_Bounds;

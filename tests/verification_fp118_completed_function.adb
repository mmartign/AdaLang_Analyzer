package body Verification_FP118_Completed_Function with SPARK_Mode => On is

   function Checked (C : Context) return Boolean is
     (C.Ready and then C.Count > 0);

   procedure Need (C : Context) is
   begin
      null;
   end Need;

   procedure Need_Low (N : Integer) is
   begin
      null;
   end Need_Low;

   procedure Need_Single (N : Integer) is
   begin
      null;
   end Need_Single;

   procedure Another_Object (Known, Other : Context) is
   begin
      Need (Other);
   end Another_Object;

   procedure Same_Object (Known, Other : Context) is
   begin
      Need (Known);
   end Same_Object;

   procedure Another_Number (Known_N, Other_N : Integer) is
   begin
      Need_Low (Other_N);
   end Another_Number;

   procedure Same_Number (Known_N, Other_N : Integer) is
   begin
      Need_Low (Known_N);
   end Same_Number;

   procedure Defaulted (Doubled : Integer) is
   begin
      Need_Single (Doubled);
   end Defaulted;

end Verification_FP118_Completed_Function;

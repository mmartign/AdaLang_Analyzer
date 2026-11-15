package body Verification_Literal_Bounds with SPARK_Mode is

   procedure Take (X : Text) is null;
   procedure Take_Short (X : Short_Text) is null;
   procedure Log (Description : String) is null;
   procedure Log_Three (Description : String) is null;
   procedure Need_Line (S : String) is null;

   procedure Run (S : String; M : Message) is
   begin
      Take ("./System/cert.dat");
      Take ("");
      Take_Short ("abc");
      Log ("abc" & "def");
      Log ("abc" & S);
      Log ("ab" & 'c' & S);
      Log_Three ("a" & "bc");
      Need_Line (M.Data);
      Need_Line (M.Line);
   end Run;

end Verification_Literal_Bounds;

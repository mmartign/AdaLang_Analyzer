package body Sample with SPARK_Mode is

   procedure Copy (Source : Vector; Target : out Vector) is
   begin
      Target := Source;
   end Copy;

   procedure Divide_By_Zero (Result : out Integer) is
      Zero : Integer := 0;
   begin
      Result := 10 / Zero;
   end Divide_By_Zero;


   procedure Through_Output (Result : out Integer) is
      Local : Integer;

      procedure Give with Global => (Output => Local) is
      begin
         Local := 1;
      end Give;
   begin
      Give;
      Result := Local;
   end Through_Output;

end Sample;

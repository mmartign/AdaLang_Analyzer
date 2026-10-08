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

end Sample;

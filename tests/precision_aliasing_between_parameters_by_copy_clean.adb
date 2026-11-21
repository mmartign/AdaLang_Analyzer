--  Aliasing_Between_Parameters: an object of a scalar type passed both to
--  an in parameter and to an in out (or out) one is well defined: the in
--  formal is a copy taken when the call is made (RM 6.2), and SPARK allows
--  it (SPARK RM 6.4.2): "To_Hour_Minute_Seconds (Seconds, Hour, Minute,
--  Seconds)" in stephes_ada_library, OpenGLAda's "Get_Shader_Source (Id,
--  Length, Length, Source)".

procedure Precision_Aliasing_Between_Parameters_By_Copy_Clean is
   procedure Update (A : in out Integer; B : in Integer) is
   begin
      A := B;
   end Update;
   X : Integer := 1;
begin
   Update (X, X);
end Precision_Aliasing_Between_Parameters_By_Copy_Clean;

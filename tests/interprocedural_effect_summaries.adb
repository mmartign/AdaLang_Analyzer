procedure Interprocedural_Effect_Summaries is
   Denominator : Integer := 0;
   Changed     : Integer := 1;
   Result      : Integer;
   Maybe_Result : Integer;
   Shadow_Result : Integer;

   procedure Observe (Value : Integer) is
   begin
      if Value < 0 then
         null;
      end if;
   end Observe;

   procedure Initialize (Value : out Integer) is
   begin
      Value := 42;
   end Initialize;

   procedure Maybe_Initialize
     (Value : out Integer;
      Do_It : Boolean) is
   begin
      if Do_It then
         Value := 7;
      end if;
   end Maybe_Initialize;

   procedure Shadowed_Initialize (Value : out Integer) is
   begin
      declare
         Value : Integer := 8;
      begin
         Value := 9;
      end;
   end Shadowed_Initialize;

   procedure Change_Outer is
      Alias : Integer renames Changed;
   begin
      Alias := 2;
   end Change_Outer;

   procedure Change_Outer_Transitively is
   begin
      Change_Outer;
   end Change_Outer_Transitively;
begin
   Observe (Denominator);
   pragma Assert (Denominator = 0);

   Initialize (Result);
   pragma Assert (Result = Result);

   Maybe_Initialize (Maybe_Result, Denominator > 0);
   pragma Assert (Maybe_Result = Maybe_Result);

   Shadowed_Initialize (Shadow_Result);
   pragma Assert (Shadow_Result = Shadow_Result);

   Change_Outer_Transitively;
   pragma Assert (Denominator = 0);
   pragma Assert (Changed = 1);

   Result := 10 / Denominator;
end Interprocedural_Effect_Summaries;

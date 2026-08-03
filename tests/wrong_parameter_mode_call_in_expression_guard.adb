procedure Wrong_Parameter_Mode_Call_In_Expression_Guard is

   --  Same call-in-expression shape as the clean sibling, but "Other" is
   --  never forwarded to Step at all -- only read via the "if" condition
   --  -- so it is genuinely read-only and "use mode in" must still fire.
   type Step_Result is (Ok, Failed);

   function Step
     (Input      : Boolean;
      Bad_Return : in out Boolean) return Step_Result
   is
   begin
      Bad_Return := Bad_Return or else not Input;
      return (if Bad_Return then Failed else Ok);
   end Step;

   function Run
     (Bad_Return : in out Boolean;
      Other      : in out Boolean) return Step_Result
   is
      Result : Step_Result;
   begin
      if Other then
         Result := Step (True, Bad_Return);
      else
         Result := Step (False, Bad_Return);
      end if;
      return Result;
   end Run;

   B, O : Boolean := False;
   R    : Step_Result;
begin
   R := Run (B, O);
end Wrong_Parameter_Mode_Call_In_Expression_Guard;

procedure Wrong_Parameter_Mode_Call_In_Expression_Clean is

   --  A function with an in-out formal, called for its return value
   --  inside a larger expression (here, an assignment's RHS) rather than
   --  as its own call statement. Checks.Declarations.Parameter_Is_Written's
   --  Ada_Assign_Stmt case only ever checked the assignment's own
   --  destination for Param -- it never gave the RHS a chance to be
   --  recognized as a write via the Ada_Call_Expr case that already
   --  handles a call statement's out/in-out actuals, because that whole
   --  case always returns before falling through to the generic child
   --  recursion where that case lives. "Bad_Return" here is both read
   --  (correctly detected by the already-correct Parameter_Is_Read) and
   --  written (forwarded in-out) by "Result := Step (..., Bad_Return);",
   --  so "in out" is the correct mode and no recommendation should fire.
   type Step_Result is (Ok, Failed);

   function Step
     (Input      : Boolean;
      Bad_Return : in out Boolean) return Step_Result
   is
   begin
      Bad_Return := Bad_Return or else not Input;
      return (if Bad_Return then Failed else Ok);
   end Step;

   function Run (Bad_Return : in out Boolean) return Step_Result is
      Result : Step_Result;
   begin
      Result := Step (True, Bad_Return);
      return Result;
   end Run;

   B : Boolean := False;
   R : Step_Result;
begin
   R := Run (B);
end Wrong_Parameter_Mode_Call_In_Expression_Clean;

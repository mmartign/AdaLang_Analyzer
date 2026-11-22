--  Constant_Condition: the same shape as the clean sibling, but the
--  function called with no actual writes nothing the condition reads: Good
--  keeps the value it was given, and the condition is always true (FP-174).

procedure Precision_Constant_Condition_No_Actual_Call_Finding
  (Tag : String; Code : out Integer)
is
   Good : Boolean := False;

   function Determine_Tag return String is
   begin
      return Tag;
   end Determine_Tag;

   Latest : constant String := Determine_Tag;
begin
   if not Good then
      Code := 1;
      return;
   end if;
   Code := Latest'Length;
end Precision_Constant_Condition_No_Actual_Call_Finding;

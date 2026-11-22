--  Constant_Condition: a function declared in the procedure, called with no
--  actual, writes objects of the procedure as up-level objects: in an
--  initial value, ravenadm's "latest_version : constant String :=
--  determine_tag;", in an assignment, and in a condition. A condition on
--  those objects after the call is not known from what they held before
--  (FP-174).

procedure Precision_Constant_Condition_No_Actual_Call_Clean
  (Tag : String; Code : out Integer)
is
   function Determine_Tag return String;
   function Mark return Integer;

   Available : Boolean := True;
   Good      : Boolean := False;
   Seen      : Boolean := False;
   Marked    : Boolean := False;

   function Determine_Tag return String is
   begin
      if Tag = "latest" then
         Good := True;
         Available := Tag'Length > 3;
         return "head";
      else
         return Tag;
      end if;
   end Determine_Tag;

   function Mark return Integer is
   begin
      Marked := True;
      return 1;
   end Mark;

   Latest : constant String := Determine_Tag;
   Count  : Integer;
begin
   if not Available or else not Good then
      Code := 1;
      return;
   end if;
   Count := Mark;
   if not Marked then
      Code := 2;
      return;
   end if;
   Marked := False;
   if Mark > 0 then
      Seen := True;
   end if;
   if not Marked or else not Seen then
      Code := 3;
      return;
   end if;
   Code := Latest'Length + Count;
end Precision_Constant_Condition_No_Actual_Call_Clean;

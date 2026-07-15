--  Negative fixture for the restricted-construct, complexity, data-flow,
--  style, and expression checks added alongside the original rule set.
procedure New_Checks_Clean is

   function Add (X, Y : Integer) return Integer is
      Sum : constant Integer := X + Y;
   begin
      return Sum;
   end Add;

   function Double (X : Integer) return Integer is
   begin
      return Add (X, X);
   end Double;

   procedure Narrow_Params (A, B : Integer) is
   begin
      null;
   end Narrow_Params;

   procedure Shallow_Nesting (N : Integer) is
      Value : Integer := N;
   begin
      if N > 0 then
         if N > 1 then
            Value := Value + 1;
         end if;
      end if;
   end Shallow_Nesting;

   procedure Show_Branches (N : Integer) is
   begin
      if N > 0 then
         null;
      elsif N < 0 then
         null;
      else
         null;
      end if;
   end Show_Branches;

   procedure Guarded_Return (N : Integer) is
   begin
      if N > 0 then
         return;
      end if;
   end Guarded_Return;

   Flag : Boolean := True;
   Result : Integer;
begin
   Result := Double (Add (1, 2));
   Narrow_Params (1, 2);
   Shallow_Nesting (Result);
   Show_Branches (Result);
   Guarded_Return (Result);

   if Flag and then Flag then
      Result := Result + 1;
   end if;
end New_Checks_Clean;

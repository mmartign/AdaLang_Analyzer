procedure Automotive_Semantic_Clean is
   type Value_Type is record
      Value : Integer;
   end record;

   procedure Operate (Value : in out Value_Type) is
   begin
      Value.Value := Value.Value + 1;
   end Operate;

   procedure Fail_Locally is
   begin
      raise Program_Error;
   end Fail_Locally;

   Item : Value_Type := (Value => 0);
begin
   Operate (Item);
   begin
      Fail_Locally;
   exception
      when Program_Error =>
         null;
   end;
end Automotive_Semantic_Clean;

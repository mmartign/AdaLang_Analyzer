procedure Precision_Anonymous_Access_Type_Finding is
   Value : aliased Integer := 0;
   Ref   : access Integer := Value'Access;
begin
   Ref.all := 1;
end Precision_Anonymous_Access_Type_Finding;

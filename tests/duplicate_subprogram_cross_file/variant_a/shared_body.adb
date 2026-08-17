procedure Shared_Body (X, Y : Integer; Result : out Integer) is
begin
   if X > Y then
      Result := X;
   else
      Result := Y;
   end if;
end Shared_Body;

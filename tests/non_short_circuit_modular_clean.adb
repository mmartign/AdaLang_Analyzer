procedure Non_Short_Circuit_Modular_Clean is
   type Flags_Type is mod 256;
   Flags : Flags_Type := 5;
   Mask  : Flags_Type := 3;
begin
   if (Flags and Mask) /= 0 then
      null;
   end if;
end Non_Short_Circuit_Modular_Clean;

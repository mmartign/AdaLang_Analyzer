with Precision_Global_Pack, Precision_Global_Ops;
use Precision_Global_Pack;
use Precision_Global_Ops;
procedure Precision_Use_Clause is
   package Local is
      J : Integer := 1;
   end Local;
   use Local, Precision_Global_Pack;
begin
   I := J;
end Precision_Use_Clause;

with Precision_Side_Effect_Pkg; use Precision_Side_Effect_Pkg;

procedure Precision_Actual_Parameter is
   Limit : Integer := 1;
   Other : Integer := 2;
begin
   Bar (Limit, 1, 2);
   Bar (Other, 1, Limit);
end Precision_Actual_Parameter;

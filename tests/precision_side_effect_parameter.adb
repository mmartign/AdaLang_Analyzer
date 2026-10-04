with Precision_Side_Effect_Pkg; use Precision_Side_Effect_Pkg;

procedure Precision_Side_Effect_Parameter is
begin
   Bar (Fun, 1, Fun1 (Fun));
   Bar (Fun, 1, Fun1 (2));
end Precision_Side_Effect_Parameter;

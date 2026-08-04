with Dep_Pkg;

procedure Verification_Cross_Project_Clean (Result : out Integer) is
begin
   Result := Dep_Pkg.Make ("Trivial");
end Verification_Cross_Project_Clean;

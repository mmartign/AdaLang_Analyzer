--  Outside SPARK code no dereference check is raised: GNATprove checks SPARK
--  code alone, and what an access value designates may there be reached by
--  names the symbolic state does not follow.
procedure Verification_Dereferences_Ada (P : access Integer; N : out Integer)
is
begin
   N := P.all;
end Verification_Dereferences_Ada;

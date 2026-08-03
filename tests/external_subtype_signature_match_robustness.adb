with Interfaces;
procedure External_Subtype_Signature_Match_Robustness is

   --  A plain subtype of a scalar type from a with'd, externally defined
   --  package (Interfaces.Integer_16 here; any with'd package's scalar
   --  type reproduces it) makes Libadalang's own property implementation
   --  raise Property_Error ("dereferencing a null access") whenever
   --  ordinary semantic analysis needs that subtype's privacy/type while
   --  matching a subprogram body against a separately declared spec.
   --  Confirmed via two independent symbolic backtraces, both bottoming
   --  out in the same Libadalang chain: Subtype_Decl_P_Get_Type ->
   --  Base_Subtype_Decl_P_From_Type_Bound -> Base_Subtype_Decl_P_Is_Private
   --  -> Base_Type_Decl_P_Next_Part, reached both from
   --  Subprogram_Summaries.Register_Body's Body.P_Decl_Part (resolving
   --  Foo's separate declaration to build its interprocedural summary)
   --  and from SPARK_Readiness.Check_Discriminant_Access's name
   --  resolution on an unrelated Dotted_Name. This is an upstream
   --  Libadalang defect, not an AdaLang Analyzer logic error: both call
   --  sites already contain it correctly via their own "when others"
   --  handler and log a "skipping ..." diagnostic rather than aborting
   --  the run, but the net effect is a real coverage gap -- no
   --  interprocedural summary is registered for Foo, and the discriminant
   --  check silently does not run on the Dotted_Name -- for any
   --  subprogram whose profile mentions such a subtype. First observed in
   --  AdaCore/Certyflie's crazyflie_support/src/types.ads
   --  ("subtype T_Int32 is Interfaces.Integer_32;" and siblings), reduced
   --  to this minimal single-file case. See known_analysis_issues.tsv,
   --  FP-029 (open; no local fix is possible, since the failure originates
   --  entirely inside vendored Libadalang).
   package Types is
      subtype T_Int16 is Interfaces.Integer_16;
   end Types;

   package Pkg is
      procedure Foo (X : Types.T_Int16);
   end Pkg;

   package body Pkg is
      procedure Foo (X : Types.T_Int16) is
      begin
         null;
      end Foo;
   end Pkg;

begin
   null;
end External_Subtype_Signature_Match_Robustness;

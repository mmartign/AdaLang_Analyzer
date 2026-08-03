with Interfaces;
procedure External_Subtype_Signature_Match_Robustness is

   --  A plain subtype of a scalar type from a with'd, externally defined
   --  package (Interfaces.Integer_16 here; any with'd package's scalar
   --  type reproduces it) makes Libadalang's own property implementation
   --  intermittently raise Property_Error ("dereferencing a null access")
   --  whenever ordinary semantic analysis needs that subtype's
   --  privacy/type while matching a subprogram body against a separately
   --  declared spec. Confirmed via two independent symbolic backtraces,
   --  both bottoming out in the same Libadalang chain:
   --  Subtype_Decl_P_Get_Type -> Base_Subtype_Decl_P_From_Type_Bound ->
   --  Base_Subtype_Decl_P_Is_Private -> Base_Type_Decl_P_Next_Part,
   --  reached both from Subprogram_Summaries.Register_Body's
   --  Body.P_Decl_Part (resolving Foo's separate declaration to build its
   --  interprocedural summary) and from
   --  SPARK_Readiness.Check_Discriminant_Access's name resolution on an
   --  unrelated Dotted_Name. This is an upstream Libadalang defect, not
   --  an AdaLang Analyzer logic error: both call sites contain it via
   --  their own "when others" handler and log a "skipping ..."
   --  diagnostic rather than aborting the run.
   --
   --  This has been re-investigated (see known_analysis_issues.tsv,
   --  FP-029) with two further findings. First, Register_Body's fallback
   --  path -- using Subprogram itself as the key declaration when
   --  P_Decl_Part fails -- was previously unreachable for exactly this
   --  failure: a Property_Error raised while elaborating a declare
   --  block's own declarative part is not handled by that block's own
   --  handlers (RM 11.2), so it escaped straight past the intended narrow
   --  handler to Register_Body's coarser outer one, which discards the
   --  whole summary. Register_Body now assigns Decl_Part in the
   --  executable part instead, so the narrow handler is reachable as
   --  originally intended -- but this does not close the gap here,
   --  because the fallback (Declaration_Name on the body, which itself
   --  needs to mangle Foo's parameter types into a unique name) hits the
   --  identical upstream defect one step later and fails the same way.
   --  Second, and more surprising: across repeated runs of one identical
   --  binary against this identical input, the failure was NOT always
   --  reproducible -- it failed consistently in long back-to-back runs,
   --  yet a single run nested inside the wider test suite succeeded with
   --  no failure at all (see run_cli_robustness.sh, which now tolerates
   --  either outcome). That pattern -- same code, same input, different
   --  outcome -- points to genuine memory-safety undefined behavior
   --  inside vendored Libadalang (e.g. a read of not-yet-initialized
   --  memory whose apparent value depends on incidental allocator
   --  history) rather than a deterministic logic branch, which is also
   --  why no reliable code-level workaround was found on this side of
   --  the boundary. First observed in AdaCore/Certyflie's
   --  crazyflie_support/src/types.ads ("subtype T_Int32 is
   --  Interfaces.Integer_32;" and siblings), reduced to this minimal
   --  single-file case. See known_analysis_issues.tsv, FP-029 (open; no
   --  reliable local fix is possible).
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

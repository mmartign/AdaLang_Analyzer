--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Langkit_Support.Text;
with Libadalang.Analysis;
with Libadalang.Common;

with Adalang_Analyzer.Rules;

--  Helpers shared by the opt-in policy check packages (Coding_Standard,
--  Readability, Typed_Policy, Object_Policy, Naming, Representation,
--  Suggestions): ancestor queries, check-parameter access and the
--  per-check exception boundary. Private to the Checks subsystem.
private package Adalang_Analyzer.Checks.Policy_Support is

   subtype Node_Kind is Libadalang.Common.Ada_Node_Kind_Type;

   function On (Rule : Rules.Rule_Kind) return Boolean;
   --  True when Rule is enabled.

   procedure Report_Finding
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Node    : Libadalang.Analysis.Ada_Node'Class;
      Rule    : Rules.Rule_Kind;
      Message : String);
   --  Reports a violation of Rule. A finding on a declaration is located
   --  at its defining name, not at its first keyword: that is where
   --  GNATcheck reports it, and the two differ when a specification
   --  starts on an earlier line than the name.

   procedure Guarded
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Node    : Libadalang.Analysis.Ada_Node'Class;
      Enabled : Boolean;
      Check   : not null access procedure
        (Unit : Libadalang.Analysis.Analysis_Unit;
         Node : Libadalang.Analysis.Ada_Node'Class));
   --  Runs Check on Node when Enabled, with its own exception boundary: a
   --  Libadalang property failure is counted as a skipped check on Node
   --  and does not reach the caller.

   function Has_Ancestor
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Match : not null access function (Kind : Node_Kind) return Boolean)
      return Boolean;
   --  True when some syntactic ancestor of Node has a kind Match accepts.

   function Count_Ancestors
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Match : not null access function (Kind : Node_Kind) return Boolean)
      return Natural;
   --  The number of syntactic ancestors of Node whose kind Match accepts.

   function Has_Semantic_Ancestor
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Match : not null access function (Kind : Node_Kind) return Boolean)
      return Boolean;
   --  As Has_Ancestor, following semantic parents: a body's parent is then
   --  the scope of its declaration, not the unit it is written in.

   function Has_Local_Scope
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Node is a generic formal object's declaration or is
   --  declared in a subprogram, task body, entry body, protected body or
   --  block.

   function Referenced
     (Name : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node;
   --  The declaration Name denotes, or a null node when Name is not a
   --  name or cannot be resolved.

   function Canonical_Exception
     (Name : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node;
   --  The exception declaration Name denotes, looking through exception
   --  renamings.

   procedure For_Each_Below
     (Root               : Libadalang.Analysis.Ada_Node'Class;
      Visit              : not null access procedure
        (Item : Libadalang.Analysis.Ada_Node);
      Skip_Nested_Bodies : Boolean := False);
   --  Calls Visit on every node below Root, in source order. With
   --  Skip_Nested_Bodies, the bodies nested in Root are left out.

   function Is_Listed (Item : String; List : String) return Boolean;
   --  True when Item is one of the comma-separated entries of List,
   --  compared without regard to case or surrounding blanks.

   function Is_Set (Rule : Rules.Rule_Kind; Name : String) return Boolean;
   --  True when the check parameter Name of Rule is "true".

   function Text_Parameter
     (Rule : Rules.Rule_Kind; Name : String) return String;
   --  The check parameter Name of Rule, or "" when it is not set.

   function Aspect_Name
     (Name : String) return Langkit_Support.Text.Unbounded_Text_Type;
   --  Name in the form Libadalang's aspect queries take.

   function Has_Aspect
     (Decl : Libadalang.Analysis.Basic_Decl'Class; Name : String)
      return Boolean;
   --  True when Decl has the aspect Name, by aspect, pragma or clause.

   function Lower (Text : String) return String;
   --  Text in lower case.

end Adalang_Analyzer.Checks.Policy_Support;

--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Termination: the obligation that a subprogram returns.
--
--  SPARK requires it of every function and of a procedure that has, or is
--  declared in a package that has, the aspect Always_Terminates; a generic
--  package that has not the aspect gets it from the place where it is
--  instantiated. The obligation is raised at the name of the subprogram in
--  its first declaration, which is where GNATprove reports its own check.
--
--  It is proved when the body is seen to terminate: it has no loop other
--  than a for loop over a discrete range or an array, no goto, no tasking
--  or delay, it calls nothing through an access value or by dispatching,
--  it is not recursive, directly or through what it calls, and each
--  subprogram it calls is seen to terminate in the same way from its own
--  body. A call to a generic formal subprogram terminates when the
--  subprogram that each instantiation in the run gives it does. A
--  predefined operation, an intrinsic and a function of a
--  language-defined unit are taken to terminate. Calls that the source
--  does not show (a subtype predicate, a default initialization, a
--  finalization) are not followed.
--
--  Everything else is Unproved: the analysis never claims that a
--  subprogram does not terminate.
package Adalang_Analyzer.Termination is

   procedure Reset;
   --  Forgets what earlier runs established.

   function Is_Library_Unit_Entity
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean;
   --  True when Decl is declared in a unit of the language-defined library
   --  or of the GNAT one, whose bodies are not followed.

   function Is_Bounded_Iteration
     (Spec : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Spec, a for loop specification, iterates "in" over a
   --  discrete range or subtype or "of" over an array: an iteration that
   --  ends by itself and runs no code of its own. Any other iteration
   --  calls the operations of an iterator.

   function Given_In
     (Instance : Libadalang.Analysis.Generic_Instantiation'Class;
      Actual   : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Actual, which Libadalang pairs with a generic formal of
   --  Instance, is written in Instance: not the default of the formal.

   procedure Resolve_Box
     (Instance   : Libadalang.Analysis.Generic_Instantiation'Class;
      Formal     : Libadalang.Analysis.Basic_Decl'Class;
      Decl       : out Libadalang.Analysis.Basic_Decl;
      Predefined : out Boolean);
   --  The subprogram that Formal, a generic formal subprogram of default
   --  <>, takes in Instance when no actual is given there: the subprogram
   --  of its name visible at the instantiation (Ada RM 12.6(10)). That is
   --  taken to be the primitive of the actual type of its first parameter
   --  that has its name and number of parameters; else, for "=" or "/=" of
   --  a type whose equality is that of scalars, or an ordering operator of
   --  a scalar type or of an array type of discrete components, the
   --  predefined operator (Predefined, Decl null). When another subprogram
   --  of the name, whose first parameter may be of that type, is declared
   --  in a region around the instantiation, or in a package a use clause
   --  there names, it could be the one taken: nothing is resolved then.
   --  Decl null and Predefined False when not resolved.

   procedure Verify_Unit (Unit : Libadalang.Analysis.Analysis_Unit);
   --  Raises the termination obligation of each subprogram body and
   --  expression function in Unit that SPARK requires to terminate, and of
   --  each generic formal procedure whose null default an instantiation
   --  takes where termination is required: that null procedure returns.

end Adalang_Analyzer.Termination;

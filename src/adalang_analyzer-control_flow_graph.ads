--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Vectors;

with Libadalang.Analysis;

--  A structural control-flow graph for the sequential verification subset.
--  The graph deliberately over-approximates exceptional flow: an executable
--  operation that may perform a run-time check has an exceptional edge to
--  the innermost handler dispatcher, or to the subprogram exceptional exit.
--  This makes the graph suitable as a future proof-analysis foundation;
--  later analyses may prove individual exceptional edges infeasible.
package Adalang_Analyzer.Control_Flow_Graph is

   subtype Node_Id is Natural;
   No_Node : constant Node_Id := 0;

   type Node_Kind is
     (Entry_Node,
      Normal_Exit_Node,
      Exceptional_Exit_Node,
      Statement_Node,
      Condition_Node,
      Declaration_Node,
      Merge_Node,
      Loop_Header_Node,
      Exception_Dispatch_Node,
      Handler_Node,
      Unsupported_Node);

   type Edge_Kind is
     (Normal_Edge,
      True_Edge,
      False_Edge,
      Case_Edge,
      Loop_Back_Edge,
      Loop_Exit_Edge,
      Return_Edge,
      Raise_Edge,
      Exceptional_Edge,
      Handler_Edge,
      Unsupported_Edge);

   type CFG_Node is record
      Id        : Node_Id := No_Node;
      Kind      : Node_Kind := Statement_Node;
      Source    : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Supported : Boolean := True;
   end record;

   type CFG_Edge is record
      From : Node_Id := No_Node;
      To   : Node_Id := No_Node;
      Kind : Edge_Kind := Normal_Edge;
   end record;

   type Graph is private;

   function Build
     (Subprogram : Libadalang.Analysis.Subp_Body) return Graph;
   --  Builds a graph with one entry and two distinguished exits. Normal
   --  completion and return reach Normal_Exit; uncaught explicit or implicit
   --  exceptions reach Exceptional_Exit.

   function Node_Count (Item : Graph) return Natural;
   function Edge_Count (Item : Graph) return Natural;
   function Node_At (Item : Graph; Id : Node_Id) return CFG_Node;
   function Edge_At (Item : Graph; Index : Positive) return CFG_Edge;

   function Entry_Id (Item : Graph) return Node_Id;
   function Normal_Exit (Item : Graph) return Node_Id;
   function Exceptional_Exit (Item : Graph) return Node_Id;

   function Is_Complete (Item : Graph) return Boolean;
   --  False when a statement outside the supported sequential subset, or a
   --  named loop exit whose target has not been resolved, was encountered.

   function Unsupported_Count (Item : Graph) return Natural;
   function Is_Well_Formed (Item : Graph) return Boolean;
   --  Checks identifier/index consistency, edge endpoints, distinct special
   --  nodes, absence of outgoing exit edges, and an outgoing edge for every
   --  non-exit node.

   function Count (Item : Graph; Kind : Node_Kind) return Natural;
   function Count (Item : Graph; Kind : Edge_Kind) return Natural;

private

   package Node_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => CFG_Node);
   package Edge_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => CFG_Edge);

   type Graph is record
      Nodes              : Node_Vectors.Vector;
      Edges              : Edge_Vectors.Vector;
      Entry_Id           : Node_Id := No_Node;
      Normal_Exit_Id     : Node_Id := No_Node;
      Exceptional_Exit_Id : Node_Id := No_Node;
      Unsupported_Nodes  : Natural := 0;
   end record;

end Adalang_Analyzer.Control_Flow_Graph;

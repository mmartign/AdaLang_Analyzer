--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Text_IO;

with Libadalang.Analysis;
with Libadalang.Common;

with Adalang_Analyzer.Control_Flow_Graph;
use Adalang_Analyzer.Control_Flow_Graph;

procedure Control_Flow_Graph_Model_Test is

   use type Libadalang.Common.Ada_Node_Kind_Type;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Check;

   function Find_Subprogram
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Subp_Body
   is
   begin
      if Node.Kind = Libadalang.Common.Ada_Subp_Body then
         return Node.As_Subp_Body;
      end if;

      for Index in 1 .. Node.Children_Count loop
         declare
            Child : constant Libadalang.Analysis.Ada_Node :=
              Node.Child (Index);
            Found : Libadalang.Analysis.Subp_Body;
         begin
            if not Libadalang.Analysis.Is_Null (Child) then
               Found := Find_Subprogram (Child);
               if not Libadalang.Analysis.Is_Null (Found) then
                  return Found;
               end if;
            end if;
         end;
      end loop;
      return Libadalang.Analysis.No_Subp_Body;
   end Find_Subprogram;

   Context : constant Libadalang.Analysis.Analysis_Context :=
     Libadalang.Analysis.Create_Context;
   Unit    : Libadalang.Analysis.Analysis_Unit;
begin
   Unit := Context.Get_From_File ("tests/control_flow_graph_fixture.adb");
   Check (not Unit.Has_Diagnostics, "supported CFG fixture did not parse");

   declare
      Subprogram : constant Libadalang.Analysis.Subp_Body :=
        Find_Subprogram (Unit.Root);
      Item       : constant Graph := Build (Subprogram);
   begin
      Check (not Libadalang.Analysis.Is_Null (Subprogram),
             "supported fixture body was not found");
      Check (Is_Complete (Item), "supported sequential CFG is incomplete");
      Check (Is_Well_Formed (Item), "supported CFG is structurally invalid");
      Check (Node_Count (Item) > 20, "CFG omitted executable structure");
      Check (Entry_Id (Item) /= No_Node, "CFG entry is missing");
      Check (Normal_Exit (Item) /= Exceptional_Exit (Item),
             "normal and exceptional exits were conflated");
      Check (Count (Item, Condition_Node) >= 4,
             "if, elsif, exit-when, or case condition is missing");
      Check (Count (Item, Loop_Header_Node) = 1,
             "loop header was not modeled exactly once");
      Check (Count (Item, True_Edge) >= 2,
             "conditional true edges are missing");
      Check (Count (Item, False_Edge) >= 2,
             "conditional false edges are missing");
      Check (Count (Item, Case_Edge) = 2,
             "case alternatives were not modeled");
      Check (Count (Item, Loop_Back_Edge) >= 1,
             "loop back edge is missing");
      Check (Count (Item, Loop_Exit_Edge) >= 2,
             "loop condition or exit-when edge is missing");
      Check (Count (Item, Return_Edge) = 1,
             "explicit return edge is missing");
      Check (Count (Item, Raise_Edge) >= 2,
             "explicit raise or reraising edge is missing");
      Check (Count (Item, Exceptional_Edge) > 0,
             "implicit exceptional flow is missing");
      Check (Count (Item, Exception_Dispatch_Node) = 2,
             "begin/declare block exception dispatchers are missing");
      Check (Count (Item, Handler_Node) = 3,
             "exception handlers were not represented");
      Check (Count (Item, Handler_Edge) = 3,
             "handler dispatch edges are missing");
   end;

   Unit := Context.Get_From_File ("tests/control_flow_graph_unsupported.adb");
   Check (not Unit.Has_Diagnostics, "unsupported CFG fixture did not parse");

   declare
      Item : constant Graph := Build (Find_Subprogram (Unit.Root));
   begin
      Check (not Is_Complete (Item),
             "goto was silently accepted into the supported subset");
      Check (Is_Well_Formed (Item), "incomplete CFG is structurally invalid");
      Check (Unsupported_Count (Item) = 1,
             "unsupported construct count is unstable");
      Check (Count (Item, Unsupported_Edge) = 1,
             "unsupported conservative continuation is missing");
   end;

   Ada.Text_IO.Put_Line ("control-flow graph model tests passed");
end Control_Flow_Graph_Model_Test;

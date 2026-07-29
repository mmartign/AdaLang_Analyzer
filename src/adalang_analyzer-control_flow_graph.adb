--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Common;

package body Adalang_Analyzer.Control_Flow_Graph is

   use type Libadalang.Common.Ada_Node_Kind_Type;

   function Node_Count (Item : Graph) return Natural is
     (Natural (Item.Nodes.Length));

   function Edge_Count (Item : Graph) return Natural is
     (Natural (Item.Edges.Length));

   function Node_At (Item : Graph; Id : Node_Id) return CFG_Node is
   begin
      if Id = No_Node or else Id > Node_Count (Item) then
         raise Constraint_Error with "invalid CFG node identifier";
      end if;
      return Item.Nodes.Element (Positive (Id));
   end Node_At;

   function Edge_At (Item : Graph; Index : Positive) return CFG_Edge is
   begin
      return Item.Edges.Element (Index);
   end Edge_At;

   function Entry_Id (Item : Graph) return Node_Id is (Item.Entry_Id);

   function Normal_Exit (Item : Graph) return Node_Id is
     (Item.Normal_Exit_Id);

   function Exceptional_Exit (Item : Graph) return Node_Id is
     (Item.Exceptional_Exit_Id);

   function Is_Complete (Item : Graph) return Boolean is
     (Item.Unsupported_Nodes = 0);

   function Unsupported_Count (Item : Graph) return Natural is
     (Item.Unsupported_Nodes);

   function Is_Well_Formed (Item : Graph) return Boolean is
      Incoming : array (1 .. Node_Count (Item)) of Natural := (others => 0);
      Outgoing : array (1 .. Node_Count (Item)) of Natural := (others => 0);
   begin
      if Node_Count (Item) < 3
        or else Item.Entry_Id = No_Node
        or else Item.Normal_Exit_Id = No_Node
        or else Item.Exceptional_Exit_Id = No_Node
        or else Item.Entry_Id = Item.Normal_Exit_Id
        or else Item.Entry_Id = Item.Exceptional_Exit_Id
        or else Item.Normal_Exit_Id = Item.Exceptional_Exit_Id
      then
         return False;
      end if;

      for Index in 1 .. Node_Count (Item) loop
         if Item.Nodes.Element (Index).Id /= Index then
            return False;
         end if;
      end loop;

      for Edge of Item.Edges loop
         if Edge.From = No_Node
           or else Edge.To = No_Node
           or else Edge.From > Node_Count (Item)
           or else Edge.To > Node_Count (Item)
         then
            return False;
         end if;
         Outgoing (Edge.From) := Outgoing (Edge.From) + 1;
         Incoming (Edge.To) := Incoming (Edge.To) + 1;
      end loop;

      if Incoming (Item.Entry_Id) /= 0
        or else Outgoing (Item.Normal_Exit_Id) /= 0
        or else Outgoing (Item.Exceptional_Exit_Id) /= 0
      then
         return False;
      end if;

      for Index in 1 .. Node_Count (Item) loop
         if Index /= Item.Normal_Exit_Id
           and then Index /= Item.Exceptional_Exit_Id
           and then Outgoing (Index) = 0
         then
            return False;
         end if;
      end loop;
      return True;
   end Is_Well_Formed;

   function Count (Item : Graph; Kind : Node_Kind) return Natural is
      Result : Natural := 0;
   begin
      for Node of Item.Nodes loop
         if Node.Kind = Kind then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Count;

   function Count (Item : Graph; Kind : Edge_Kind) return Natural is
      Result : Natural := 0;
   begin
      for Edge of Item.Edges loop
         if Edge.Kind = Kind then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Count;

   function Build
     (Subprogram : Libadalang.Analysis.Subp_Body) return Graph
   is
      Result : Graph;

      type Loop_Context is record
         Exit_Target : Node_Id := No_Node;
      end record;
      package Loop_Context_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Loop_Context);
      Loop_Stack : Loop_Context_Vectors.Vector;

      function Add_Node
        (Kind      : Node_Kind;
         Source    : Libadalang.Analysis.Ada_Node :=
           Libadalang.Analysis.No_Ada_Node;
         Supported : Boolean := True) return Node_Id
      is
         Id : constant Node_Id := Node_Count (Result) + 1;
      begin
         Result.Nodes.Append
           ((Id => Id, Kind => Kind, Source => Source, Supported => Supported));
         if not Supported then
            Result.Unsupported_Nodes := Result.Unsupported_Nodes + 1;
         end if;
         return Id;
      end Add_Node;

      procedure Add_Edge
        (From : Node_Id; To : Node_Id; Kind : Edge_Kind) is
      begin
         if From = No_Node or else To = No_Node then
            raise Program_Error with "CFG edge has an unresolved endpoint";
         end if;
         Result.Edges.Append ((From => From, To => To, Kind => Kind));
      end Add_Edge;

      function Handles_Others
        (Handler : Libadalang.Analysis.Exception_Handler) return Boolean
      is
      begin
         for Choice of Handler.F_Handled_Exceptions loop
            if Choice.Kind = Libadalang.Common.Ada_Others_Designator then
               return True;
            end if;
         end loop;
         return False;
      end Handles_Others;

      function Build_List
        (List               : Libadalang.Analysis.Ada_Node'Class;
         Continuation       : Node_Id;
         Exception_Target   : Node_Id;
         Return_Target      : Node_Id) return Node_Id;

      function Build_Handled
        (Handled            : Libadalang.Analysis.Handled_Stmts;
         Continuation       : Node_Id;
         Outer_Exception    : Node_Id;
         Return_Target      : Node_Id) return Node_Id;

      function Build_Declarations
        (Declarations       : Libadalang.Analysis.Ada_Node'Class;
         Continuation       : Node_Id;
         Exception_Target   : Node_Id) return Node_Id
      is
         Current : Node_Id := Continuation;
      begin
         if Libadalang.Analysis.Is_Null (Declarations) then
            return Current;
         end if;

         for Index in reverse 1 .. Declarations.Children_Count loop
            declare
               Decl : constant Libadalang.Analysis.Ada_Node :=
                 Declarations.Child (Index);
               Id   : constant Node_Id :=
                 Add_Node (Declaration_Node, Decl);
            begin
               Add_Edge (Id, Current, Normal_Edge);
               --  Declaration elaboration can evaluate bounds and
               --  initializers. Its exception precedes installation of the
               --  handlers belonging to the same handled sequence.
               Add_Edge (Id, Exception_Target, Exceptional_Edge);
               Current := Id;
            end;
         end loop;
         return Current;
      end Build_Declarations;

      function Build_Else_Chain
        (Stmt               : Libadalang.Analysis.If_Stmt;
         Index              : Positive;
         Continuation       : Node_Id;
         Exception_Target   : Node_Id;
         Return_Target      : Node_Id) return Node_Id
      is
         Alternatives : constant Libadalang.Analysis.Elsif_Stmt_Part_List :=
           Stmt.F_Alternatives;
      begin
         if Index > Alternatives.Children_Count then
            if Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
               return Continuation;
            end if;
            return Build_List
              (Stmt.F_Else_Part.F_Stmts, Continuation, Exception_Target,
               Return_Target);
         end if;

         declare
            Alt       : constant Libadalang.Analysis.Elsif_Stmt_Part :=
              Alternatives.Child (Index).As_Elsif_Stmt_Part;
            Cond      : constant Node_Id :=
              Add_Node
                (Condition_Node,
                 Libadalang.Analysis.Ada_Node (Alt.F_Cond_Expr));
            True_Path : constant Node_Id :=
              Build_List
                (Alt.F_Stmts, Continuation, Exception_Target, Return_Target);
            False_Path : constant Node_Id :=
              Build_Else_Chain
                (Stmt, Index + 1, Continuation, Exception_Target,
                 Return_Target);
         begin
            Add_Edge (Cond, True_Path, True_Edge);
            Add_Edge (Cond, False_Path, False_Edge);
            Add_Edge (Cond, Exception_Target, Exceptional_Edge);
            return Cond;
         end;
      end Build_Else_Chain;

      function Build_Statement
        (Stmt               : Libadalang.Analysis.Ada_Node;
         Continuation       : Node_Id;
         Exception_Target   : Node_Id;
         Return_Target      : Node_Id) return Node_Id
      is
         use Libadalang.Common;
      begin
         case Stmt.Kind is
            when Ada_Assign_Stmt
               | Ada_Call_Stmt
               | Ada_Simple_Decl_Stmt
               | Ada_Pragma_Node =>
               declare
                  Id : constant Node_Id := Add_Node (Statement_Node, Stmt);
               begin
                  Add_Edge (Id, Continuation, Normal_Edge);
                  Add_Edge (Id, Exception_Target, Exceptional_Edge);
                  return Id;
               end;

            when Ada_Null_Stmt | Ada_Label =>
               declare
                  Id : constant Node_Id := Add_Node (Statement_Node, Stmt);
               begin
                  Add_Edge (Id, Continuation, Normal_Edge);
                  return Id;
               end;

            when Ada_Return_Stmt =>
               declare
                  Id : constant Node_Id := Add_Node (Statement_Node, Stmt);
               begin
                  Add_Edge (Id, Return_Target, Return_Edge);
                  --  Evaluating a returned expression may raise.
                  Add_Edge (Id, Exception_Target, Exceptional_Edge);
                  return Id;
               end;

            when Ada_Raise_Stmt =>
               declare
                  Id : constant Node_Id := Add_Node (Statement_Node, Stmt);
               begin
                  Add_Edge (Id, Exception_Target, Raise_Edge);
                  return Id;
               end;

            when Ada_Exit_Stmt =>
               declare
                  Exit_Statement : constant Libadalang.Analysis.Exit_Stmt :=
                    Stmt.As_Exit_Stmt;
                  Conditional    : constant Boolean :=
                    not Libadalang.Analysis.Is_Null
                      (Exit_Statement.F_Cond_Expr);
                  Named          : constant Boolean :=
                    not Libadalang.Analysis.Is_Null
                      (Exit_Statement.F_Loop_Name);
                  Supported      : constant Boolean :=
                    not Loop_Stack.Is_Empty and then not Named;
                  Id             : constant Node_Id :=
                    Add_Node
                       ((if not Supported then Unsupported_Node
                         elsif Conditional then Condition_Node
                         else Statement_Node),
                       Stmt, Supported);
                  Target         : constant Node_Id :=
                    (if Loop_Stack.Is_Empty
                     then Continuation
                     else Loop_Stack.Last_Element.Exit_Target);
               begin
                  if Conditional then
                     Add_Edge (Id, Target, Loop_Exit_Edge);
                     Add_Edge (Id, Continuation, False_Edge);
                     Add_Edge (Id, Exception_Target, Exceptional_Edge);
                  else
                     Add_Edge
                       (Id, Target,
                        (if Supported then Loop_Exit_Edge
                         else Unsupported_Edge));
                  end if;
                  return Id;
               end;

            when Ada_If_Stmt =>
               declare
                  If_Node    : constant Libadalang.Analysis.If_Stmt :=
                    Stmt.As_If_Stmt;
                  Cond       : constant Node_Id :=
                    Add_Node
                      (Condition_Node,
                       Libadalang.Analysis.Ada_Node
                         (If_Node.F_Cond_Expr));
                  True_Path  : constant Node_Id :=
                    Build_List
                      (If_Node.F_Then_Stmts, Continuation, Exception_Target,
                       Return_Target);
                  False_Path : constant Node_Id :=
                    Build_Else_Chain
                      (If_Node, 1, Continuation, Exception_Target,
                       Return_Target);
               begin
                  Add_Edge (Cond, True_Path, True_Edge);
                  Add_Edge (Cond, False_Path, False_Edge);
                  Add_Edge (Cond, Exception_Target, Exceptional_Edge);
                  return Cond;
               end;

            when Ada_Case_Stmt =>
               declare
                  Case_Node : constant Libadalang.Analysis.Case_Stmt :=
                    Stmt.As_Case_Stmt;
                  Choice    : constant Node_Id :=
                    Add_Node
                      (Condition_Node,
                       Libadalang.Analysis.Ada_Node (Case_Node.F_Expr));
               begin
                  for Alternative of Case_Node.F_Alternatives loop
                     Add_Edge
                       (Choice,
                        Build_List
                          (Alternative.As_Case_Stmt_Alternative.F_Stmts,
                           Continuation, Exception_Target, Return_Target),
                        Case_Edge);
                  end loop;
                  Add_Edge (Choice, Exception_Target, Exceptional_Edge);
                  return Choice;
               end;

            when Ada_While_Loop_Stmt
               | Ada_For_Loop_Stmt
               | Ada_Loop_Stmt =>
               declare
                  Header : constant Node_Id :=
                    Add_Node (Loop_Header_Node, Stmt);
                  Back_Edge_Node : constant Node_Id :=
                    Add_Node (Merge_Node);
                  Body_Entry : Node_Id;
               begin
                  Loop_Stack.Append ((Exit_Target => Continuation));
                  Body_Entry := Build_List
                    (Stmt.As_Base_Loop_Stmt.F_Stmts, Back_Edge_Node,
                     Exception_Target, Return_Target);
                  Loop_Stack.Delete_Last;

                  Add_Edge (Back_Edge_Node, Header, Loop_Back_Edge);
                  Add_Edge
                    (Header, Body_Entry,
                     (if Stmt.Kind = Ada_Loop_Stmt then Normal_Edge
                      else True_Edge));
                  if Stmt.Kind /= Ada_Loop_Stmt then
                     Add_Edge (Header, Continuation, Loop_Exit_Edge);
                     Add_Edge
                       (Header, Exception_Target, Exceptional_Edge);
                  end if;
                  return Header;
               end;

            when Ada_Begin_Block =>
               return Build_Handled
                 (Stmt.As_Begin_Block.F_Stmts, Continuation,
                  Exception_Target, Return_Target);

            when Ada_Decl_Block =>
               declare
                  Block      : constant Libadalang.Analysis.Decl_Block :=
                    Stmt.As_Decl_Block;
                  Body_Entry : constant Node_Id :=
                    Build_Handled
                      (Block.F_Stmts, Continuation, Exception_Target,
                       Return_Target);
               begin
                  return Build_Declarations
                    (Block.F_Decls.F_Decls, Body_Entry, Exception_Target);
               end;

            when others =>
               declare
                  Id : constant Node_Id :=
                    Add_Node (Unsupported_Node, Stmt, False);
               begin
                  Add_Edge (Id, Continuation, Unsupported_Edge);
                  Add_Edge (Id, Exception_Target, Exceptional_Edge);
                  return Id;
               end;
         end case;
      end Build_Statement;

      function Build_List
        (List               : Libadalang.Analysis.Ada_Node'Class;
         Continuation       : Node_Id;
         Exception_Target   : Node_Id;
         Return_Target      : Node_Id) return Node_Id
      is
         Current : Node_Id := Continuation;
      begin
         if Libadalang.Analysis.Is_Null (List) then
            return Current;
         end if;

         for Index in reverse 1 .. List.Children_Count loop
            declare
               Stmt : constant Libadalang.Analysis.Ada_Node :=
                 List.Child (Index);
            begin
               if not Libadalang.Analysis.Is_Null (Stmt) then
                  Current := Build_Statement
                    (Stmt, Current, Exception_Target, Return_Target);
               end if;
            end;
         end loop;
         return Current;
      end Build_List;

      function Build_Handled
        (Handled            : Libadalang.Analysis.Handled_Stmts;
         Continuation       : Node_Id;
         Outer_Exception    : Node_Id;
         Return_Target      : Node_Id) return Node_Id
      is
      begin
         if Handled.F_Exceptions.Children_Count = 0 then
            return Build_List
              (Handled.F_Stmts, Continuation, Outer_Exception,
               Return_Target);
         end if;

         declare
            Dispatch      : constant Node_Id :=
              Add_Node (Exception_Dispatch_Node);
            Catches_All   : Boolean := False;
         begin
            for Handler_Node_Source of Handled.F_Exceptions loop
               declare
                  Handler : constant Libadalang.Analysis.Exception_Handler :=
                    Handler_Node_Source.As_Exception_Handler;
                  Marker  : constant Node_Id :=
                    Add_Node
                      (Handler_Node,
                       Libadalang.Analysis.Ada_Node (Handler));
                  Handler_Body : constant Node_Id :=
                    Build_List
                      (Handler.F_Stmts, Continuation, Outer_Exception,
                       Return_Target);
               begin
                  Add_Edge (Dispatch, Marker, Handler_Edge);
                  Add_Edge (Marker, Handler_Body, Normal_Edge);
                  Catches_All := Catches_All or else Handles_Others (Handler);
               end;
            end loop;

            if not Catches_All then
               Add_Edge (Dispatch, Outer_Exception, Exceptional_Edge);
            end if;

            return Build_List
              (Handled.F_Stmts, Continuation, Dispatch, Return_Target);
         end;
      end Build_Handled;

      Body_Entry : Node_Id;
      Full_Entry : Node_Id;
   begin
      Result.Entry_Id := Add_Node (Entry_Node);
      Result.Normal_Exit_Id := Add_Node (Normal_Exit_Node);
      Result.Exceptional_Exit_Id := Add_Node (Exceptional_Exit_Node);

      Body_Entry := Build_Handled
        (Subprogram.F_Stmts, Result.Normal_Exit_Id,
         Result.Exceptional_Exit_Id, Result.Normal_Exit_Id);
      Full_Entry := Build_Declarations
        (Subprogram.F_Decls.F_Decls, Body_Entry,
         Result.Exceptional_Exit_Id);
      Add_Edge (Result.Entry_Id, Full_Entry, Normal_Edge);
      return Result;
   end Build;

end Adalang_Analyzer.Control_Flow_Graph;

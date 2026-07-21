--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;   use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;     use Adalang_Analyzer.Config;
with Adalang_Analyzer.Report;     use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;      use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils; use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.SPARK_Readiness is

   use type Ada.Containers.Count_Type;
   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Basic_Decl;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   type Access_Info is record
      Key        : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Name       : Unbounded_String;
      Site       : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Is_Read    : Boolean := False;
      Is_Written : Boolean := False;
   end record;

   package Access_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Access_Info);

   function Contract_Expression
     (Decl : Libadalang.Analysis.Basic_Decl'Class;
      Name : String) return Libadalang.Analysis.Expr
   is
      Result : Libadalang.Analysis.Expr;
   begin
      Result := Decl.P_Get_Aspect_Spec_Expr
        (Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text (Name)));
      if Libadalang.Analysis.Is_Null (Result)
        and then Decl.Kind = Libadalang.Common.Ada_Subp_Body
      then
         declare
            Decl_Part : constant Libadalang.Analysis.Basic_Decl :=
              Decl.As_Subp_Body.P_Decl_Part
                (Imprecise_Fallback => True);
         begin
            if not Libadalang.Analysis.Is_Null (Decl_Part) then
               Result := Decl_Part.P_Get_Aspect_Spec_Expr
                 (Langkit_Support.Text.To_Unbounded_Text
                    (Langkit_Support.Text.To_Text (Name)));
            end if;
         end;
      end if;
      return Result;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Contract_Expression;

   function Effective_SPARK_Enabled
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Aspect : Libadalang.Analysis.Aspect;
   begin
      Aspect := Decl.P_Get_Aspect
        (Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text ("SPARK_Mode")));
      return not Libadalang.Analysis.Exists (Aspect)
        or else Libadalang.Analysis.Is_Null
          (Libadalang.Analysis.Value (Aspect))
        or else Normalize_Rule_Name
          (Node_Text (Libadalang.Analysis.Value (Aspect))) /= "off";
   exception
      when others =>
         return True;
   end Effective_SPARK_Enabled;

   function Is_Within
     (Decl : Libadalang.Analysis.Basic_Decl;
      Root : Libadalang.Analysis.Subp_Body) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Decl);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current = Libadalang.Analysis.Ada_Node (Root) then
            return True;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   end Is_Within;

   function Referenced_Object_Key
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Root : Libadalang.Analysis.Subp_Body)
      return Libadalang.Analysis.Ada_Node
   is
      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      Decl := Node.As_Name.P_Referenced_Decl (Imprecise_Fallback => True);
      if Libadalang.Analysis.Is_Null (Decl)
        or else Decl.Kind /= Libadalang.Common.Ada_Object_Decl
        or else Is_Within (Decl, Root)
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;
      return Libadalang.Analysis.Ada_Node
        (Node.As_Name.P_Referenced_Defining_Name);
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Referenced_Object_Key;

   function Is_Parameter_Key
     (Key : Libadalang.Analysis.Ada_Node) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node := Key;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Param_Spec then
            return True;
         elsif Current.Kind = Libadalang.Common.Ada_Object_Decl then
            return False;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   end Is_Parameter_Key;

   function Equivalent_Keys
     (Left, Right : Libadalang.Analysis.Ada_Node) return Boolean is
     (Left = Right
      or else
        (Is_Parameter_Key (Left)
         and then Is_Parameter_Key (Right)
         and then Normalize_Rule_Name (Node_Text (Left)) =
           Normalize_Rule_Name (Node_Text (Right))));

   function Find
     (Items : Access_Vectors.Vector;
      Key   : Libadalang.Analysis.Ada_Node) return Natural
   is
   begin
      for I in Items.First_Index .. Items.Last_Index loop
         if Equivalent_Keys (Items (I).Key, Key) then
            return I;
         end if;
      end loop;
      return 0;
   exception
      when Constraint_Error =>
         return 0;
   end Find;

   procedure Include
     (Items      : in out Access_Vectors.Vector;
      Key        : Libadalang.Analysis.Ada_Node;
      Name       : String;
      Site       : Libadalang.Analysis.Ada_Node'Class;
      Is_Read    : Boolean;
      Is_Written : Boolean)
   is
      Index : constant Natural := Find (Items, Key);
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      elsif Index = 0 then
         Items.Append
           ((Key        => Key,
             Name       => To_Unbounded_String (Name),
             Site       => Libadalang.Analysis.Ada_Node (Site),
             Is_Read    => Is_Read,
             Is_Written => Is_Written));
      else
         Items (Index).Is_Read := Items (Index).Is_Read or else Is_Read;
         Items (Index).Is_Written :=
           Items (Index).Is_Written or else Is_Written;
      end if;
   end Include;

   procedure Include_Identifier
     (Items      : in out Access_Vectors.Vector;
      Node       : Libadalang.Analysis.Ada_Node'Class;
      Root       : Libadalang.Analysis.Subp_Body;
      Is_Read    : Boolean;
      Is_Written : Boolean)
   is
      Key : constant Libadalang.Analysis.Ada_Node :=
        Referenced_Object_Key (Node, Root);
   begin
      if not Libadalang.Analysis.Is_Null (Key) then
         Include
           (Items, Key, Node_Text (Node), Node, Is_Read, Is_Written);
      end if;
   end Include_Identifier;

   procedure Collect_Contract_Objects
     (Expr       : Libadalang.Analysis.Ada_Node'Class;
      Root       : Libadalang.Analysis.Subp_Body;
      Site       : Libadalang.Analysis.Ada_Node'Class;
      Is_Read    : Boolean;
      Is_Written : Boolean;
      Items      : in out Access_Vectors.Vector)
   is
   begin
      if Libadalang.Analysis.Is_Null (Expr) then
         return;
      elsif Expr.Kind = Libadalang.Common.Ada_Identifier then
         declare
            Key : constant Libadalang.Analysis.Ada_Node :=
              Referenced_Object_Key (Expr, Root);
         begin
            if not Libadalang.Analysis.Is_Null (Key) then
               Include
                 (Items, Key, Node_Text (Expr), Site, Is_Read, Is_Written);
            end if;
         end;
         return;
      end if;

      for I in 1 .. Expr.Children_Count loop
         Collect_Contract_Objects
           (Expr.Child (I), Root, Site, Is_Read, Is_Written, Items);
      end loop;
   end Collect_Contract_Objects;

   procedure Parse_Global
     (Expr  : Libadalang.Analysis.Expr;
      Root  : Libadalang.Analysis.Subp_Body;
      Site  : Libadalang.Analysis.Ada_Node'Class;
      Items : in out Access_Vectors.Vector)
   is
   begin
      if Libadalang.Analysis.Is_Null (Expr)
        or else Expr.Kind = Libadalang.Common.Ada_Null_Literal
      then
         return;
      elsif Expr.Kind not in Libadalang.Common.Ada_Base_Aggregate then
         Collect_Contract_Objects
           (Expr, Root, Site, Is_Read => True, Is_Written => False,
            Items => Items);
         return;
      end if;

      for Item of Expr.As_Base_Aggregate.F_Assocs loop
         if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
            declare
               Assoc : constant Libadalang.Analysis.Aggregate_Assoc :=
                 Item.As_Aggregate_Assoc;
               Mode  : constant String :=
                 (if Assoc.F_Designators.Children_Count = 0 then "input"
                  else Normalize_Rule_Name
                    (Node_Text (Assoc.F_Designators.Child (1))));
               Reads : constant Boolean :=
                 Mode = "input" or else Mode = "in-out"
                   or else Mode = "proof-in";
               Writes : constant Boolean :=
                 Mode = "output" or else Mode = "in-out";
            begin
               Collect_Contract_Objects
                 (Assoc.F_R_Expr, Root, Site, Reads, Writes, Items);
            end;
         end if;
      end loop;
   end Parse_Global;

   function Formal_Mode
     (Param : Libadalang.Analysis.Defining_Name'Class)
      return Libadalang.Common.Ada_Node_Kind_Type
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Param);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Param_Spec then
            return Current.As_Param_Spec.F_Mode.Kind;
         end if;
         Current := Current.Parent;
      end loop;
      return Libadalang.Common.Ada_Mode_Default;
   exception
      when others =>
         return Libadalang.Common.Ada_Mode_Default;
   end Formal_Mode;

   procedure Collect_Accesses
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Root  : Libadalang.Analysis.Subp_Body;
      Items : in out Access_Vectors.Vector;
      As_Write : Boolean := False);

   procedure Collect_Call
     (Call  : Libadalang.Analysis.Name'Class;
      Root  : Libadalang.Analysis.Subp_Body;
      Items : in out Access_Vectors.Vector)
   is
      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      for Pair of Call.P_Call_Params loop
         declare
            Mode : constant Libadalang.Common.Ada_Node_Kind_Type :=
              Formal_Mode (Libadalang.Analysis.Param (Pair));
         begin
            if Mode = Libadalang.Common.Ada_Mode_Out then
               Collect_Accesses
                 (Libadalang.Analysis.Actual (Pair), Root, Items,
                  As_Write => True);
            elsif Mode = Libadalang.Common.Ada_Mode_In_Out then
               Collect_Accesses
                 (Libadalang.Analysis.Actual (Pair), Root, Items);
               Collect_Accesses
                 (Libadalang.Analysis.Actual (Pair), Root, Items,
                  As_Write => True);
            else
               Collect_Accesses
                 (Libadalang.Analysis.Actual (Pair), Root, Items);
            end if;
         end;
      end loop;

      begin
         if Call.Kind = Libadalang.Common.Ada_Call_Expr then
            Decl := Call.As_Call_Expr.F_Name.P_Referenced_Decl;
         else
            Decl := Call.P_Referenced_Decl;
         end if;
         if not Libadalang.Analysis.Is_Null (Decl) then
            declare
               Global : constant Libadalang.Analysis.Expr :=
                 Contract_Expression (Decl, "Global");
            begin
               Parse_Global (Global, Root, Call, Items);
            end;
         end if;
      exception
         when others =>
            null;
      end;
   exception
      when others =>
         --  Resolution failure loses precision but must never turn into a
         --  guessed contract violation.
         null;
   end Collect_Call;

   procedure Collect_Accesses
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Root  : Libadalang.Analysis.Subp_Body;
      Items : in out Access_Vectors.Vector;
      As_Write : Boolean := False)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Subp_Body then
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
         Collect_Accesses
           (Node.As_Assign_Stmt.F_Dest, Root, Items, As_Write => True);
         Collect_Accesses (Node.As_Assign_Stmt.F_Expr, Root, Items);
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
         Collect_Call (Node.As_Call_Expr.F_Name, Root, Items);
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Call_Stmt then
         Collect_Call (Node.As_Call_Stmt.F_Call, Root, Items);
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Identifier then
         Include_Identifier
           (Items, Node, Root,
            Is_Read => not As_Write, Is_Written => As_Write);
         return;
      end if;

      for I in 1 .. Node.Children_Count loop
         Collect_Accesses (Node.Child (I), Root, Items, As_Write);
      end loop;
   end Collect_Accesses;

   function Same_Parameter
     (Node   : Libadalang.Analysis.Ada_Node'Class;
      Param  : Libadalang.Analysis.Param_Spec;
      Name   : String) return Boolean
   is
      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
        or else Normalize_Rule_Name (Node_Text (Node)) /= Name
      then
         return False;
      end if;
      Decl := Node.As_Name.P_Referenced_Decl (Imprecise_Fallback => True);
      return Libadalang.Analysis.Is_Null (Decl)
        or else Decl = Libadalang.Analysis.Basic_Decl (Param);
   exception
      when others =>
         return True;
   end Same_Parameter;

   function Statement_Writes_Parameter
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Param : Libadalang.Analysis.Param_Spec;
      Name  : String) return Boolean
   is
   begin
      if Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
         return Same_Parameter (Node.As_Assign_Stmt.F_Dest, Param, Name);
      elsif Node.Kind = Libadalang.Common.Ada_Call_Stmt then
         for Pair of Node.As_Call_Stmt.F_Call.P_Call_Params loop
            if Formal_Mode (Libadalang.Analysis.Param (Pair)) =
                 Libadalang.Common.Ada_Mode_Out
              and then Same_Parameter
                (Libadalang.Analysis.Actual (Pair), Param, Name)
            then
               return True;
            end if;
         end loop;
      end if;
      return False;
   exception
      when others =>
         return False;
   end Statement_Writes_Parameter;

   type Init_Result is record
      Can_Fall_Through : Boolean := True;
      Initialized      : Boolean := False;
   end record;

   function Merge (Left, Right : Init_Result) return Init_Result is
   begin
      if not Left.Can_Fall_Through then
         return Right;
      elsif not Right.Can_Fall_Through then
         return Left;
      else
         return
           (Can_Fall_Through => True,
            Initialized => Left.Initialized and then Right.Initialized);
      end if;
   end Merge;

   function Interpret_Initialization
     (Node        : Libadalang.Analysis.Ada_Node'Class;
      Param       : Libadalang.Analysis.Param_Spec;
      Name        : String;
      Initial     : Boolean;
      Bad_Return  : in out Boolean) return Init_Result;

   function Interpret_List
     (List        : Libadalang.Analysis.Ada_Node'Class;
      Param       : Libadalang.Analysis.Param_Spec;
      Name        : String;
      Initial     : Boolean;
      Bad_Return  : in out Boolean) return Init_Result
   is
      Result : Init_Result :=
        (Can_Fall_Through => True, Initialized => Initial);
   begin
      for I in 1 .. List.Children_Count loop
         exit when not Result.Can_Fall_Through;
         Result := Interpret_Initialization
           (List.Child (I), Param, Name, Result.Initialized, Bad_Return);
      end loop;
      return Result;
   end Interpret_List;

   function Interpret_Initialization
     (Node        : Libadalang.Analysis.Ada_Node'Class;
      Param       : Libadalang.Analysis.Param_Spec;
      Name        : String;
      Initial     : Boolean;
      Bad_Return  : in out Boolean) return Init_Result
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return (True, Initial);
      elsif Statement_Writes_Parameter (Node, Param, Name) then
         return (True, True);
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt =>
            Bad_Return := Bad_Return or else not Initial;
            return (False, Initial);

         when Libadalang.Common.Ada_Raise_Stmt
            | Libadalang.Common.Ada_Goto_Stmt =>
            return (False, Initial);

         when Libadalang.Common.Ada_If_Stmt =>
            declare
               Stmt   : constant Libadalang.Analysis.If_Stmt :=
                 Node.As_If_Stmt;
               Result : Init_Result := Interpret_List
                 (Stmt.F_Then_Stmts, Param, Name, Initial, Bad_Return);
            begin
               for Alt of Stmt.F_Alternatives loop
                  Result := Merge
                    (Result,
                     Interpret_List
                       (Alt.F_Stmts, Param, Name, Initial, Bad_Return));
               end loop;
               if Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
                  Result := Merge (Result, (True, Initial));
               else
                  Result := Merge
                    (Result,
                     Interpret_List
                       (Stmt.F_Else_Part.F_Stmts, Param, Name, Initial,
                        Bad_Return));
               end if;
               return Result;
            end;

         when Libadalang.Common.Ada_Case_Stmt =>
            declare
               First  : Boolean := True;
               Result : Init_Result := (False, Initial);
            begin
               for Alt of Node.As_Case_Stmt.F_Alternatives loop
                  declare
                     Branch : constant Init_Result := Interpret_List
                       (Alt.F_Stmts, Param, Name, Initial, Bad_Return);
                  begin
                     if First then
                        Result := Branch;
                        First := False;
                     else
                        Result := Merge (Result, Branch);
                     end if;
                  end;
               end loop;
               return Result;
            end;

         when Libadalang.Common.Ada_Decl_Block =>
            return Interpret_List
              (Node.As_Decl_Block.F_Stmts.F_Stmts, Param, Name, Initial,
               Bad_Return);

         when Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_While_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt =>
            --  Inspect returns inside the body, but do not assume that a loop
            --  initializes an output: even a plain loop can leave through an
            --  exit before the assignment.
            declare
               Ignored : constant Init_Result := Interpret_List
                 (Node.As_Base_Loop_Stmt.F_Stmts, Param, Name, Initial,
                  Bad_Return);
               pragma Unreferenced (Ignored);
            begin
               return (True, Initial);
            end;

         when others =>
            return (True, Initial);
      end case;
   end Interpret_Initialization;

   procedure Collect_Depends_Outputs
     (Expr    : Libadalang.Analysis.Expr;
      Outputs : in out Access_Vectors.Vector)
   is
   begin
      if Libadalang.Analysis.Is_Null (Expr)
        or else Expr.Kind not in Libadalang.Common.Ada_Base_Aggregate
      then
         return;
      end if;

      for Item of Expr.As_Base_Aggregate.F_Assocs loop
         if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
            for Designator of Item.As_Aggregate_Assoc.F_Designators loop
               if Designator.Kind = Libadalang.Common.Ada_Identifier then
                  declare
                     Key : constant Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Ada_Node
                         (Designator.As_Name.P_Referenced_Defining_Name);
                  begin
                     if not Libadalang.Analysis.Is_Null (Key) then
                        Include
                          (Outputs, Key, Node_Text (Designator), Designator,
                           Is_Read => False, Is_Written => True);
                     end if;
                  exception
                     when others =>
                        null;
                  end;
               end if;
            end loop;
         end if;
      end loop;
   end Collect_Depends_Outputs;

   procedure Analyze_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Needs_Analysis : constant Boolean :=
        Rule_States (Missing_Global_Contract) = Enabled
        or else Rule_States (Global_Contract_Mismatch) = Enabled
        or else Rule_States (Missing_Depends_Contract) = Enabled
        or else Rule_States (Incomplete_Depends_Contract) = Enabled
        or else Rule_States (Uninitialized_Output) = Enabled;
      Actual_Global   : Access_Vectors.Vector;
      Declared_Global : Access_Vectors.Vector;
      Outputs         : Access_Vectors.Vector;
      Depends_Outputs : Access_Vectors.Vector;
      Global          : Libadalang.Analysis.Expr;
      Depends         : Libadalang.Analysis.Expr;
      Name_Node       : constant Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Subprogram.F_Subp_Spec.P_Name);
   begin
      if not Needs_Analysis or else not Effective_SPARK_Enabled (Subprogram)
      then
         return;
      end if;

      Global := Contract_Expression (Subprogram, "Global");
      Depends := Contract_Expression (Subprogram, "Depends");
      Collect_Accesses (Subprogram.F_Stmts, Subprogram, Actual_Global);
      Parse_Global (Global, Subprogram, Name_Node, Declared_Global);

      if Rule_States (Missing_Global_Contract) = Enabled
        and then Actual_Global.Length > 0
        and then Libadalang.Analysis.Is_Null (Global)
      then
         Report_Rule_Violation
           (Unit, Name_Node, Missing_Global_Contract,
            "subprogram accesses global state but has no Global contract");
      end if;

      if Rule_States (Global_Contract_Mismatch) = Enabled
        and then not Libadalang.Analysis.Is_Null (Global)
      then
         for Actual of Actual_Global loop
            declare
               Index : constant Natural := Find (Declared_Global, Actual.Key);
               Missing_Read, Missing_Write : Boolean := False;
            begin
               if Index = 0 then
                  Missing_Read := Actual.Is_Read;
                  Missing_Write := Actual.Is_Written;
               else
                  Missing_Read := Actual.Is_Read
                    and then not Declared_Global (Index).Is_Read;
                  Missing_Write := Actual.Is_Written
                    and then not Declared_Global (Index).Is_Written;
               end if;

               if Missing_Read or else Missing_Write then
                  Report_Rule_Violation
                    (Unit, Actual.Site, Global_Contract_Mismatch,
                     "global '" & To_String (Actual.Name) & "' is " &
                       (if Missing_Read and then Missing_Write then
                           "read and written"
                        elsif Missing_Write then "written"
                        else "read") &
                       " but its Global contract mode does not allow it");
               end if;
            end;
         end loop;
      end if;

      --  Every out/in out formal is an output for Depends. In out values are
      --  already initialized on entry, so only mode out participates in the
      --  definite-initialization check below.
      for Param of Subprogram.F_Subp_Spec.P_Params loop
         if Param.F_Mode.Kind in Libadalang.Common.Ada_Mode_Out
           | Libadalang.Common.Ada_Mode_In_Out
         then
            for Id of Param.F_Ids loop
               Include
                 (Outputs, Libadalang.Analysis.Ada_Node (Id),
                  Node_Text (Id), Id, Is_Read => False, Is_Written => True);

               if Rule_States (Uninitialized_Output) = Enabled
                 and then Param.F_Mode.Kind = Libadalang.Common.Ada_Mode_Out
               then
                  declare
                     Bad_Return : Boolean := False;
                     Result : constant Init_Result := Interpret_List
                       (Subprogram.F_Stmts.F_Stmts, Param,
                        Normalize_Rule_Name (Node_Text (Id)), False,
                        Bad_Return);
                  begin
                     if Subprogram.F_Stmts.F_Exceptions.Children_Count > 0 then
                        for Handler of Subprogram.F_Stmts.F_Exceptions loop
                           declare
                              Handler_Result : constant Init_Result :=
                                Interpret_List
                                  (Handler.As_Exception_Handler.F_Stmts, Param,
                                   Normalize_Rule_Name (Node_Text (Id)),
                                   False, Bad_Return);
                           begin
                              if Handler_Result.Can_Fall_Through
                                and then not Handler_Result.Initialized
                              then
                                 Bad_Return := True;
                              end if;
                           end;
                        end loop;
                     end if;

                     if Bad_Return
                       or else
                         (Result.Can_Fall_Through
                          and then not Result.Initialized)
                     then
                        Report_Rule_Violation
                          (Unit, Id, Uninitialized_Output,
                           "out parameter '" & Node_Text (Id) &
                             "' is not initialized on every normal return " &
                             "path");
                     end if;
                  end;
               end if;
            end loop;
         end if;
      end loop;

      for Item of Declared_Global loop
         if Item.Is_Written then
            Include
              (Outputs, Item.Key, To_String (Item.Name), Item.Site,
               Is_Read => False, Is_Written => True);
         end if;
      end loop;

      if Rule_States (Missing_Depends_Contract) = Enabled
        and then Outputs.Length > 0
        and then Libadalang.Analysis.Is_Null (Depends)
      then
         Report_Rule_Violation
           (Unit, Name_Node, Missing_Depends_Contract,
            "subprogram has outputs but no Depends contract");
      elsif Rule_States (Incomplete_Depends_Contract) = Enabled
        and then not Libadalang.Analysis.Is_Null (Depends)
      then
         Collect_Depends_Outputs (Depends, Depends_Outputs);
         for Output of Outputs loop
            if Find (Depends_Outputs, Output.Key) = 0 then
               Report_Rule_Violation
                 (Unit, Output.Site, Incomplete_Depends_Contract,
                  "output '" & To_String (Output.Name) &
                    "' has no association in the Depends contract");
            end if;
         end loop;
      end if;
   exception
      when others =>
         --  Readiness checks are deliberately best effort: incomplete name
         --  resolution must not prevent the ordinary analyzer from running.
         null;
   end Analyze_Subprogram;

end Adalang_Analyzer.SPARK_Readiness;

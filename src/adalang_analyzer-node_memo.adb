--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Hashed_Maps;

package body Adalang_Analyzer.Node_Memo is

   use type Libadalang.Analysis.Analysis_Unit;

   package Result_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Libadalang.Analysis.Ada_Node,
      Element_Type    => Result_Type,
      Hash            => Libadalang.Analysis.Hash,
      Equivalent_Keys => Libadalang.Analysis."=");

   Results : Result_Maps.Map;
   Unit    : Libadalang.Analysis.Analysis_Unit :=
     Libadalang.Analysis.No_Analysis_Unit;

   --  Its only effect is to keep what it returns, which it would return
   --  without it.
   function Get (Node : Libadalang.Analysis.Ada_Node) return Result_Type is
   begin
      if Node.Unit /= Unit then
         Results.Clear;
         Unit := Node.Unit;  --  adalang-analyzer: ignore Function_Side_Effect
      end if;
      declare
         Position : constant Result_Maps.Cursor := Results.Find (Node);
      begin
         if Result_Maps.Has_Element (Position) then
            return Result_Maps.Element (Position);
         end if;
      end;
      declare
         Result : constant Result_Type := Compute (Node);
      begin
         Results.Insert (Node, Result);
         return Result;
      end;
   end Get;

end Adalang_Analyzer.Node_Memo;

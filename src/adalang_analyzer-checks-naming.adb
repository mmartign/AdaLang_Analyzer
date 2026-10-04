--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Fixed;

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text; use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Policy_Support;
use Adalang_Analyzer.Checks.Policy_Support;
with Adalang_Analyzer.Report;   use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;    use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Checks.Naming is

   use type Libadalang.Common.Ada_Node_Kind_Type;

   function Starts_With (Text : String; Prefix : String) return Boolean
   is (Text'Length >= Prefix'Length
       and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

   function Ends_With (Text : String; Suffix : String) return Boolean
     renames Adalang_Analyzer.Text_Utils.Has_Suffix;

   --  True when Node has no earlier declaration, or only an incomplete
   --  type declaration: the place where a naming convention is checked.
   function Is_First_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Previous : Libadalang.Analysis.Ada_Node;
   begin
      if Node.Kind = Libadalang.Common.Ada_Defining_Name then
         Previous := Node.As_Defining_Name.P_Previous_Part.As_Ada_Node;
      elsif Node.Kind in Libadalang.Common.Ada_Base_Type_Decl then
         Previous := Node.As_Base_Type_Decl.P_Previous_Part.As_Ada_Node;
      elsif Node.Kind in Libadalang.Common.Ada_Body_Node then
         Previous := Node.As_Body_Node.P_Previous_Part.As_Ada_Node;
      else
         return True;
      end if;

      return Libadalang.Analysis.Is_Null (Previous)
        or else Previous.Kind in
                  Libadalang.Common.Ada_Incomplete_Type_Decl_Range;
   end Is_First_Declaration;

   --  The declaration of the type Type_Ref denotes when that is an access
   --  type, else a null node.
   function Is_Access_Typed
     (Type_Ref : Libadalang.Analysis.Type_Expr'Class) return Boolean
   is
      Designated : Libadalang.Analysis.Base_Type_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Type_Ref) then
         return False;
      end if;
      Designated := Type_Ref.P_Designated_Type_Decl;
      return not Libadalang.Analysis.Is_Null (Designated)
        and then Designated.P_Is_Access_Type;
   end Is_Access_Typed;

   function Is_Classwide
     (Type_Decl : Libadalang.Analysis.Base_Type_Decl) return Boolean
   is (not Libadalang.Analysis.Is_Null (Type_Decl)
       and then (Type_Decl.Kind = Libadalang.Common.Ada_Classwide_Type_Decl
                 or else (Type_Decl.Kind = Libadalang.Common.Ada_Subtype_Decl
                          and then Type_Decl.P_Canonical_Type.Kind =
                                     Libadalang.Common
                                       .Ada_Classwide_Type_Decl)));

   function Renames_Enumeration_Literal
     (Decl : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Renamed : constant Libadalang.Analysis.Name :=
        Decl.As_Subp_Renaming_Decl.F_Renames.F_Renamed_Object;
      Target  : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Renamed) then
         return False;
      end if;
      Target := Renamed.P_Referenced_Decl;
      return not Libadalang.Analysis.Is_Null (Target)
        and then Target.Kind = Libadalang.Common.Ada_Enum_Literal_Decl;
   exception
      when others =>
         return False;
   end Renames_Enumeration_Literal;

   --------------
   --  Casing  --
   --------------

   function Has_Wrong_Casing
     (Word   : String;
      Scheme : String)  --  adalang-analyzer: ignore Swappable_Parameters
      return Boolean
   is
      At_Start : Boolean := True;
   begin
      if Scheme = "upper" then
         return (for some C of Word => C in 'a' .. 'z');
      elsif Scheme = "lower" then
         return (for some C of Word => C in 'A' .. 'Z');
      elsif Scheme /= "mixed" then
         return False;
      end if;

      --  Mixed case: an upper-case letter starts each word, lower-case
      --  letters follow.
      for C of Word loop
         if (At_Start and then C in 'a' .. 'z')
           or else (not At_Start and then C in 'A' .. 'Z')
         then
            return True;
         end if;
         At_Start := C = '_';
      end loop;
      return False;
   end Has_Wrong_Casing;

   --  The spelling the exclusion list Exclusions imposes on Word in the
   --  given position, or "" when it imposes none. An entry applies to a
   --  whole identifier, "abc*" to a first word, "*abc" to a last word and
   --  "*abc*" to any word; the last matching entry wins.
   function Imposed_Spelling
     (Word       : String;
      Exclusions : String;  --  adalang-analyzer: ignore Swappable_Parameters
      Form       : Character) return String
   is
      Start  : Positive := Exclusions'First;
      Result : String (1 .. Word'Length) := (others => ' ');
      Found  : Boolean := False;
   begin
      for I in Exclusions'First .. Exclusions'Last + 1 loop
         if I > Exclusions'Last or else Exclusions (I) = ',' then
            declare
               Item : constant String := Ada.Strings.Fixed.Trim
                 (Exclusions (Start .. I - 1), Ada.Strings.Both);
               Leading  : constant Boolean :=
                 Item'Length > 1 and then Item (Item'First) = '*';
               Trailing : constant Boolean :=
                 Item'Length > 1 and then Item (Item'Last) = '*';
               Core     : constant String :=
                 Item ((if Leading then Item'First + 1 else Item'First) ..
                       (if Trailing then Item'Last - 1 else Item'Last));
               Applies  : constant Boolean :=
                 (case Form is
                     when 'W'    => not Leading and then not Trailing,
                     when 'F'    => Trailing and then not Leading,
                     when 'L'    => Leading and then not Trailing,
                     when others => Leading and then Trailing);
            begin
               if Applies and then Lower (Core) = Lower (Word) then
                  Result := Core;
                  Found := True;
               end if;
            end;
            Start := I + 1;
         end if;
      end loop;
      return (if Found then Result else "");
   end Imposed_Spelling;

   function Breaks_Casing
     (Name       : String;
      Scheme     : String;  --  adalang-analyzer: ignore Swappable_Parameters
      Exclusions : String)  --  adalang-analyzer: ignore Swappable_Parameters
      return Boolean
   is
      Whole : constant String := Imposed_Spelling (Name, Exclusions, 'W');
      First : Positive := Name'First;
      Last  : Natural;
   begin
      if Exclusions = "" then
         return Has_Wrong_Casing (Name, Scheme);
      elsif Whole /= "" then
         return Name /= Whole;
      end if;

      --  Word by word: an excluded word must be spelled as listed, any
      --  other word must follow the scheme.
      while First <= Name'Last loop
         Last := Ada.Strings.Fixed.Index (Name (First .. Name'Last), "_");
         Last := (if Last = 0 then Name'Last else Last - 1);
         declare
            Word     : constant String := Name (First .. Last);
            Position : constant String :=
              (if First = Name'First
               then Imposed_Spelling (Word, Exclusions, 'F') else "");
            Ending   : constant String :=
              (if Last = Name'Last
               then Imposed_Spelling (Word, Exclusions, 'L') else "");
            Anywhere : constant String :=
              Imposed_Spelling (Word, Exclusions, 'A');
         begin
            if Position /= "" then
               if Word /= Position then
                  return True;
               end if;
            elsif Ending /= "" then
               if Word /= Ending then
                  return True;
               end if;
            elsif Anywhere /= "" then
               if Word /= Anywhere then
                  return True;
               end if;
            elsif Has_Wrong_Casing (Word, Scheme) then
               return True;
            end if;
         end;
         First := Last + 2;
      end loop;
      return False;
   end Breaks_Casing;

   procedure Analyze_Casing
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      type Name_Class is
        (Type_Name, Enumeration_Literal, Constant_Name, Exception_Name,
         Other_Name);

      function Scheme (Class : Name_Class) return String
      is (Lower
            (Text_Parameter
               (Identifier_Casing,
                (case Class is
                    when Type_Name           => "type",
                    when Enumeration_Literal => "enum",
                    when Constant_Name       => "constant",
                    when Exception_Name      => "exception",
                    when Other_Name          => "others"))));

      function Label (Class : Name_Class) return String
      is (case Class is
             when Type_Name           => "type and subtype names",
             when Enumeration_Literal => "enumeration literals",
             when Constant_Name       => "constants",
             when Exception_Name      => "exceptions",
             when Other_Name          => "other names");

      Name   : constant String := Node_Text (Node.As_Defining_Name.F_Name);
      Owner  : constant Libadalang.Analysis.Ada_Node := Node.Parent;
      Outer  : constant Libadalang.Analysis.Ada_Node :=
        (if Libadalang.Analysis.Is_Null (Owner)
         then Libadalang.Analysis.No_Ada_Node else Owner.Parent);
      Kind   : constant Node_Kind := Owner.Kind;
      Chosen : Name_Class := Other_Name;
   begin
      if Node.As_Defining_Name.F_Name.Kind /= Libadalang.Common.Ada_Identifier
      then
         return;
      end if;

      if Kind in Libadalang.Common.Ada_Single_Task_Decl
           | Libadalang.Common.Ada_Single_Task_Type_Decl
      then
         Chosen := Other_Name;
      elsif Scheme (Type_Name) /= ""
        and then (Kind in Libadalang.Common.Ada_Base_Type_Decl
                  or else (Kind = Libadalang.Common.Ada_Task_Body
                           and then
                             (Libadalang.Analysis.Is_Null
                                (Owner.As_Body_Node.P_Previous_Part)
                              or else Owner.As_Body_Node.P_Previous_Part.Kind
                                      /= Libadalang.Common
                                           .Ada_Single_Task_Decl)))
      then
         Chosen := Type_Name;
      elsif Scheme (Enumeration_Literal) /= ""
        and then Kind = Libadalang.Common.Ada_Enum_Literal_Decl
      then
         Chosen := Enumeration_Literal;
      elsif not Libadalang.Analysis.Is_Null (Outer) then
         if Scheme (Constant_Name) /= ""
           and then (Outer.Kind = Libadalang.Common.Ada_Number_Decl
                     or else (Outer.Kind in
                                Libadalang.Common.Ada_Object_Decl_Range
                              and then Outer.As_Basic_Decl
                                         .P_Is_Constant_Object))
         then
            Chosen := Constant_Name;
         elsif Scheme (Enumeration_Literal) /= ""
           and then Outer.Kind = Libadalang.Common.Ada_Subp_Renaming_Decl
           and then Renames_Enumeration_Literal (Outer)
         then
            Chosen := Enumeration_Literal;
         elsif Scheme (Exception_Name) /= ""
           and then Outer.Kind = Libadalang.Common.Ada_Exception_Decl
         then
            Chosen := Exception_Name;
         end if;
      end if;

      if Breaks_Casing
           (Name, Scheme (Chosen),
            Text_Parameter (Identifier_Casing, "exclude"))
      then
         Report_Rule_Violation
           (Unit, Node, Identifier_Casing,
            Name & " does not have the casing required for "
            & Label (Chosen)
            & (if Has_Wrong_Casing (Name, Scheme (Chosen))
               then " (" & Scheme (Chosen) & ")"
               else " (see the exclusion list)"));
      end if;
   end Analyze_Casing;

   ----------------
   --  Prefixes  --
   ----------------

   type Prefix_Kind is
     (Concurrent, Class_Access, Subprogram_Access, Plain_Access, Any_Type,
      Constant_Object, Exception_Name, Enumeration);

   type Prefix_Set is array (Prefix_Kind) of Boolean;

   function Prefix_Parameter (Kind : Prefix_Kind) return String
   is (Text_Parameter
         (Identifier_Prefixes,
          (case Kind is
              when Concurrent        => "concurrent",
              when Class_Access      => "class_access",
              when Subprogram_Access => "subprogram_access",
              when Plain_Access      => "access",
              when Any_Type          => "type",
              when Constant_Object   => "constant",
              when Exception_Name    => "exception",
              when Enumeration       => "enum")));

   function Prefix_Label (Kind : Prefix_Kind) return String
   is (case Kind is
          when Concurrent        => "a concurrent type",
          when Class_Access      => "an access-to-class type",
          when Subprogram_Access => "an access-to-subprogram type",
          when Plain_Access      => "an access type",
          when Any_Type          => "a type",
          when Constant_Object   => "a constant",
          when Exception_Name    => "an exception",
          when Enumeration       => "an enumeration literal");

   --  The complaint about Name carrying a prefix reserved for another
   --  kind of entity, or "" when it carries none. Exclusive lists the
   --  kinds whose prefix Name must not use; Expected is its own prefix.
   function Foreign_Prefix
     (Name      : String;
      Expected  : String;  --  adalang-analyzer: ignore Swappable_Parameters
      Exclusive : Prefix_Set) return String
   is
   begin
      if Lower (Text_Parameter (Identifier_Prefixes, "exclusive")) = "false"
      then
         return "";
      end if;

      for Kind in Prefix_Kind loop
         declare
            Reserved : constant String := Prefix_Parameter (Kind);
         begin
            if Exclusive (Kind)
              and then Starts_With (Name, Reserved)
              and then not Starts_With (Expected, Reserved)
            then
               return Name & " is not " & Prefix_Label (Kind)
                 & " but starts with " & Reserved;
            end if;
         end;
      end loop;
      return "";
   end Foreign_Prefix;

   function Prefix_Complaint
     (Name      : String;
      Expected  : String;  --  adalang-analyzer: ignore Swappable_Parameters
      Own       : Prefix_Kind;
      Also_Free : Prefix_Set := (others => False)) return String
   is
      Exclusive : Prefix_Set := (others => True);
   begin
      if Expected /= "" and then not Starts_With (Name, Expected) then
         return Name & " does not start with the prefix " & Expected
           & " required for " & Prefix_Label (Own);
      end if;

      Exclusive (Own) := False;
      for Kind in Prefix_Kind loop
         if Also_Free (Kind) then
            Exclusive (Kind) := False;
         end if;
      end loop;
      return Foreign_Prefix (Name, Expected, Exclusive);
   end Prefix_Complaint;

   function Is_Class_Access
     (Decl : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Def : Libadalang.Analysis.Type_Def;
   begin
      if Decl.Kind not in Libadalang.Common.Ada_Type_Decl then
         return False;
      end if;
      Def := Decl.As_Type_Decl.F_Type_Def;
      return not Libadalang.Analysis.Is_Null (Def)
        and then Def.Kind = Libadalang.Common.Ada_Type_Access_Def
        and then Def.As_Type_Access_Def.F_Subtype_Indication.F_Name.Kind =
                   Libadalang.Common.Ada_Attribute_Ref
        and then Canonical_Text
                   (Def.As_Type_Access_Def.F_Subtype_Indication.F_Name
                      .As_Attribute_Ref.F_Attribute) = "class";
   end Is_Class_Access;

   --  Decl itself for a type declaration, the type it is a subtype of for
   --  a subtype declaration.
   function Underlying
     (Decl : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Decl.Kind = Libadalang.Common.Ada_Subtype_Decl then
         return Decl.As_Base_Type_Decl.P_Canonical_Type.As_Ada_Node;
      else
         return Decl.As_Ada_Node;
      end if;
   end Underlying;

   function Type_Def_Kind
     (Decl : Libadalang.Analysis.Ada_Node'Class) return Node_Kind
   is
      Target : constant Libadalang.Analysis.Ada_Node := Underlying (Decl);
   begin
      if Libadalang.Analysis.Is_Null (Target)
        or else Target.Kind not in Libadalang.Common.Ada_Type_Decl
        or else Libadalang.Analysis.Is_Null (Target.As_Type_Decl.F_Type_Def)
      then
         return Libadalang.Common.Ada_Abort_Absent;
      end if;
      return Target.As_Type_Decl.F_Type_Def.Kind;
   end Type_Def_Kind;

   --  The prefix the derived parameter ("full.type.name:prefix,...")
   --  assigns to types derived from Parent, or "".
   function Derived_Prefix
     (Parent : Libadalang.Analysis.Base_Type_Decl) return String
   is
      List  : constant String := Text_Parameter (Identifier_Prefixes, "derived");
      Start : Positive := List'First;
   begin
      if List = "" or else Libadalang.Analysis.Is_Null (Parent) then
         return "";
      end if;

      declare
         Full_Name : constant String := Lower
           (Langkit_Support.Text.To_UTF8
              (Parent.P_Canonical_Type.P_Canonical_Fully_Qualified_Name));
      begin
         for I in List'First .. List'Last + 1 loop
            if I > List'Last or else List (I) = ',' then
               declare
                  Item  : constant String := Ada.Strings.Fixed.Trim
                    (List (Start .. I - 1), Ada.Strings.Both);
                  Colon : constant Natural :=
                    Ada.Strings.Fixed.Index (Item, ":");
               begin
                  if Colon > Item'First
                    and then Lower (Item (Item'First .. Colon - 1)) = Full_Name
                  then
                     return Item (Colon + 1 .. Item'Last);
                  end if;
               end;
               Start := I + 1;
            end if;
         end loop;
      end;
      return "";
   end Derived_Prefix;

   function Prefix_Message
     (Node : Libadalang.Analysis.Ada_Node'Class) return String
   is
      Name  : constant String := Node_Text (Node.As_Defining_Name.F_Name);
      Owner : constant Libadalang.Analysis.Ada_Node := Node.Parent;
      Kind  : constant Node_Kind := Owner.Kind;
      Outer : constant Libadalang.Analysis.Ada_Node := Owner.Parent;
      Def   : Node_Kind;
   begin
      --  Task and protected types, their bodies and their subtypes.
      if Prefix_Parameter (Concurrent) /= ""
        and then Kind /= Libadalang.Common.Ada_Single_Task_Type_Decl
        and then (Kind in Libadalang.Common.Ada_Task_Type_Decl
                    | Libadalang.Common.Ada_Protected_Type_Decl
                    | Libadalang.Common.Ada_Task_Body
                    | Libadalang.Common.Ada_Protected_Body
                  or else (Kind = Libadalang.Common.Ada_Subtype_Decl
                           and then Underlying (Owner).Kind in
                                      Libadalang.Common.Ada_Task_Type_Decl
                                      | Libadalang.Common
                                          .Ada_Protected_Type_Decl))
      then
         return (if Is_First_Declaration (Owner)
                 then Prefix_Complaint
                        (Name, Prefix_Parameter (Concurrent), Concurrent)
                 else "");
      end if;

      if Kind in Libadalang.Common.Ada_Type_Decl
           | Libadalang.Common.Ada_Subtype_Decl
      then
         Def := Type_Def_Kind (Owner);

         if Prefix_Parameter (Class_Access) /= ""
           and then Is_Class_Access (Underlying (Owner))
         then
            return (if Is_First_Declaration (Owner)
                    then Prefix_Complaint
                           (Name, Prefix_Parameter (Class_Access),
                            Class_Access)
                    else "");
         elsif Prefix_Parameter (Subprogram_Access) /= ""
           and then Def = Libadalang.Common.Ada_Access_To_Subp_Def
         then
            return (if Is_First_Declaration (Owner)
                    then Prefix_Complaint
                           (Name, Prefix_Parameter (Subprogram_Access),
                            Subprogram_Access)
                    else "");
         elsif Prefix_Parameter (Plain_Access) /= ""
           and then Def in Libadalang.Common.Ada_Access_Def
         then
            return (if Is_First_Declaration (Owner)
                    then Prefix_Complaint
                           (Name, Prefix_Parameter (Plain_Access),
                            Plain_Access,
                            Also_Free => (Any_Type => True, others => False))
                    else "");
         elsif Text_Parameter (Identifier_Prefixes, "derived") /= ""
           and then (Kind = Libadalang.Common.Ada_Subtype_Decl
                     or else Def = Libadalang.Common.Ada_Derived_Type_Def)
         then
            declare
               Wanted : constant String := Derived_Prefix
                 (Owner.As_Base_Type_Decl.P_Canonical_Type.P_Base_Type);
            begin
               if Wanted /= "" then
                  if not Is_First_Declaration (Owner) then
                     return "";
                  elsif not Starts_With (Name, Wanted) then
                     return Name & " does not start with the prefix "
                       & Wanted & " required for its parent type";
                  else
                     return Foreign_Prefix (Name, Wanted, (others => True));
                  end if;
               end if;
            end;
         end if;
      end if;

      if Kind in Libadalang.Common.Ada_Incomplete_Type_Decl_Range then
         return "";
      elsif Kind in Libadalang.Common.Ada_Base_Type_Decl
        and then Kind /= Libadalang.Common.Ada_Single_Task_Type_Decl
      then
         return (if Is_First_Declaration (Owner)
                 then Prefix_Complaint
                        (Name, Prefix_Parameter (Any_Type), Any_Type)
                 else "");
      elsif Kind = Libadalang.Common.Ada_Enum_Literal_Decl then
         return Prefix_Complaint
           (Name, Prefix_Parameter (Enumeration), Enumeration);
      elsif Libadalang.Analysis.Is_Null (Outer) then
         return Foreign_Prefix (Name, "", (others => True));
      end if;

      if Outer.Kind = Libadalang.Common.Ada_Number_Decl
        or else (Outer.Kind in Libadalang.Common.Ada_Object_Decl_Range
                 and then Outer.As_Basic_Decl.P_Is_Constant_Object
                 and then Outer.Parent.Kind /=
                            Libadalang.Common.Ada_Generic_Formal_Obj_Decl)
      then
         return (if Is_First_Declaration (Node)
                 then Prefix_Complaint
                        (Name, Prefix_Parameter (Constant_Object),
                         Constant_Object)
                 else "");
      elsif Outer.Kind = Libadalang.Common.Ada_Subp_Renaming_Decl
        and then Renames_Enumeration_Literal (Outer)
      then
         return Prefix_Complaint
           (Name, Prefix_Parameter (Enumeration), Enumeration);
      elsif Outer.Kind = Libadalang.Common.Ada_Exception_Decl then
         return Prefix_Complaint
           (Name, Prefix_Parameter (Exception_Name), Exception_Name);
      elsif Outer.Kind in Libadalang.Common.Ada_Object_Decl_Range then
         return (if Is_First_Declaration (Node)
                 then Foreign_Prefix (Name, "", (others => True)) else "");
      elsif Outer.Kind in Libadalang.Common.Ada_Body_Node then
         return (if Is_First_Declaration (Outer)
                 then Foreign_Prefix (Name, "", (others => True)) else "");
      end if;

      return Foreign_Prefix (Name, "", (others => True));
   end Prefix_Message;

   procedure Analyze_Prefix
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Message : constant String := Prefix_Message (Node);
   begin
      if Message /= "" then
         Report_Rule_Violation (Unit, Node, Identifier_Prefixes, Message);
      end if;
   end Analyze_Prefix;

   ----------------
   --  Suffixes  --
   ----------------

   function Suffix_Parameter
     (Name    : String;
      Default : String)  --  adalang-analyzer: ignore Swappable_Parameters
      return String
   is
      Given : constant String := Text_Parameter (Identifier_Suffixes, Name);
   begin
      return (if Given /= "" then Given
              elsif Is_Set (Identifier_Suffixes, "default") then Default
              else "");
   end Suffix_Parameter;

   function Is_Protected_Definition (Kind : Node_Kind) return Boolean
   is (Kind = Libadalang.Common.Ada_Protected_Def);

   --  The suffix Node's name must end with and what it stands for, or ""
   --  when no suffix convention applies to it.
   procedure Required_Suffix
     (Node   : Libadalang.Analysis.Ada_Node'Class;
      Suffix : out Langkit_Support.Text.Unbounded_Text_Type;
      Label  : out Langkit_Support.Text.Unbounded_Text_Type)
   is
      Owner : constant Libadalang.Analysis.Ada_Node := Node.Parent;
      Kind  : constant Node_Kind := Owner.Kind;
      Outer : constant Libadalang.Analysis.Ada_Node := Owner.Parent;

      procedure Set (Value : String; Text : String) is  --  adalang-analyzer: ignore Swappable_Parameters
      begin
         Suffix := Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text (Value));
         Label := Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text (Text));
      end Set;

      Type_Suffix     : constant String := Suffix_Parameter ("type_suffix", "_T");
      Access_Suffix   : constant String :=
        Suffix_Parameter ("access_suffix", "_A");
      Class_Access    : constant String :=
        Suffix_Parameter ("class_access_suffix", "");
      Class_Subtype   : constant String :=
        Suffix_Parameter ("class_subtype_suffix", "");
      Constant_Suffix : constant String :=
        Suffix_Parameter ("constant_suffix", "_C");
      Renaming_Suffix : constant String :=
        Suffix_Parameter ("renaming_suffix", "_R");
      Access_Object   : constant String :=
        Suffix_Parameter ("access_obj_suffix", "");
      Interrupt       : constant String :=
        Suffix_Parameter ("interrupt_suffix", "");
   begin
      Suffix := Langkit_Support.Text.To_Unbounded_Text ("");
      Label := Langkit_Support.Text.To_Unbounded_Text ("");

      if Kind = Libadalang.Common.Ada_Subp_Spec and then Interrupt /= "" then
         if not Libadalang.Analysis.Is_Null (Outer)
           and then Outer.Kind = Libadalang.Common.Ada_Subp_Decl
           and then Has_Ancestor (Owner, Is_Protected_Definition'Access)
           and then (Has_Aspect (Outer.As_Basic_Decl, "Interrupt_Handler")
                     or else Has_Aspect (Outer.As_Basic_Decl, "Attach_Handler"))
         then
            Set (Interrupt, "interrupt handlers");
         end if;
         return;
      end if;

      if Kind in Libadalang.Common.Ada_Type_Decl
        and then Owner.As_Base_Type_Decl.P_Is_Access_Type
      then
         declare
            Target : constant Libadalang.Analysis.Base_Type_Decl :=
              Owner.As_Base_Type_Decl.P_Accessed_Type;
         begin
            if Class_Access /= "" and then Is_Classwide (Target) then
               if Is_First_Declaration (Owner) then
                  Set (Class_Access, "access-to-class types");
               end if;
               return;
            elsif Access_Suffix /= "" then
               if Is_First_Declaration (Owner) then
                  if Text_Parameter (Identifier_Suffixes,
                                     "access_access_suffix") /= ""
                    and then not Libadalang.Analysis.Is_Null (Target)
                    and then Target.P_Is_Access_Type
                  then
                     Set (Access_Suffix
                          & Text_Parameter
                              (Identifier_Suffixes, "access_access_suffix"),
                          "access-to-access types");
                  else
                     Set (Access_Suffix, "access types");
                  end if;
               end if;
               return;
            end if;
         end;
      end if;

      if Kind in Libadalang.Common.Ada_Base_Subtype_Decl
        and then Class_Subtype /= ""
        and then Owner.As_Base_Type_Decl.P_Base_Subtype.Kind =
                   Libadalang.Common.Ada_Classwide_Type_Decl
      then
         if Is_First_Declaration (Owner) then
            Set (Class_Subtype, "class-wide subtypes");
         end if;
      elsif Kind in Libadalang.Common.Ada_Type_Decl then
         if Type_Suffix /= "" and then Is_First_Declaration (Owner) then
            Set (Type_Suffix, "types");
         end if;
      elsif Kind = Libadalang.Common.Ada_Package_Renaming_Decl then
         Set (Renaming_Suffix, "package renamings");
      elsif not Libadalang.Analysis.Is_Null (Outer)
        and then Kind not in Libadalang.Common.Ada_Incomplete_Type_Decl_Range
        and then Libadalang.Analysis.Is_Null
                   (Node.As_Defining_Name.P_Previous_Part)
      then
         if Access_Object /= ""
           and then ((Outer.Kind in Libadalang.Common.Ada_Object_Decl_Range
                      and then Is_Access_Typed
                                 (Outer.As_Object_Decl.F_Type_Expr))
                     or else (Outer.Kind = Libadalang.Common.Ada_Component_Decl
                              and then Is_Access_Typed
                                         (Outer.As_Component_Decl
                                            .F_Component_Def.F_Type_Expr))
                     or else (Outer.Kind = Libadalang.Common.Ada_Param_Spec
                              and then Is_Access_Typed
                                         (Outer.As_Param_Spec.F_Type_Expr))
                     or else (Outer.Kind =
                                Libadalang.Common.Ada_Discriminant_Spec
                              and then Is_Access_Typed
                                         (Outer.As_Discriminant_Spec
                                            .F_Type_Expr)))
         then
            Set (Access_Object, "objects of an access type");
         elsif Constant_Suffix /= ""
           and then Outer.Kind in Libadalang.Common.Ada_Object_Decl_Range
           and then Outer.As_Basic_Decl.P_Is_Constant_Object
         then
            Set (Constant_Suffix, "constants");
         end if;
      end if;
   end Required_Suffix;

   procedure Analyze_Suffix
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Name   : constant String := Node_Text (Node.As_Defining_Name.F_Name);
      Suffix : Langkit_Support.Text.Unbounded_Text_Type;
      Label  : Langkit_Support.Text.Unbounded_Text_Type;
   begin
      Required_Suffix (Node, Suffix, Label);

      declare
         Wanted : constant String := Langkit_Support.Text.To_UTF8
           (Langkit_Support.Text.To_Text (Suffix));
      begin
         if Wanted /= "" and then not Ends_With (Name, Wanted) then
            Report_Rule_Violation
              (Unit, Node, Identifier_Suffixes,
               Name & " does not end with the suffix " & Wanted
               & " required for "
               & Langkit_Support.Text.To_UTF8
                   (Langkit_Support.Text.To_Text (Label)));
         end if;
      end;
   end Analyze_Suffix;

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Node.Kind /= Libadalang.Common.Ada_Defining_Name
        or else Libadalang.Analysis.Is_Null (Node.Parent)
      then
         return;
      end if;

      Guarded (Unit, Node, On (Identifier_Casing), Analyze_Casing'Access);
      Guarded (Unit, Node, On (Identifier_Prefixes), Analyze_Prefix'Access);
      Guarded (Unit, Node, On (Identifier_Suffixes), Analyze_Suffix'Access);
   end Analyze_Node;

end Adalang_Analyzer.Checks.Naming;

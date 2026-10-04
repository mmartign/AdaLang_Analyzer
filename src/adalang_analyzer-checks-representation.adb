--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text; use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Policy_Support;
use Adalang_Analyzer.Checks.Policy_Support;
with Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;    use Adalang_Analyzer.Rules;

package body Adalang_Analyzer.Checks.Representation is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   subtype Node is Libadalang.Analysis.Ada_Node;

   function Is_Null (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
     renames Libadalang.Analysis.Is_Null;

   function Is_Attribute
     (Item : Libadalang.Analysis.Ada_Node'Class; Name : String) return Boolean
   is (not Is_Null (Item)
       and then Item.Kind = Libadalang.Common.Ada_Attribute_Ref
       and then Canonical_Text (Item.As_Attribute_Ref.F_Attribute) = Name);

   function Is_Object (Item : Node) return Boolean
   is (not Is_Null (Item)
       and then Item.Kind in Libadalang.Common.Ada_Object_Decl_Range
                  | Libadalang.Common.Ada_Param_Spec);

   function Is_Constant_Object (Item : Node) return Boolean
   is (Is_Object (Item) and then Item.As_Basic_Decl.P_Is_Constant_Object);

   function Has_Aspect (Item : Node; Name : String) return Boolean
   is (not Is_Null (Item)
       and then Item.Kind in Libadalang.Common.Ada_Basic_Decl
       and then Has_Aspect (Item.As_Basic_Decl, Name));

   --  The declaration Name ultimately denotes, looking through object
   --  renamings and, when Strip_Component is set, from a component to
   --  the object that holds it. When All_Nodes is not set and Name is
   --  not a simple or expanded name, Name itself is returned.
   function Ultimate_Alias
     (Name            : Libadalang.Analysis.Ada_Node'Class;
      All_Nodes       : Boolean := True;
      Strip_Component : Boolean := False) return Node  --  adalang-analyzer: ignore Swappable_Parameters
   is
      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if not All_Nodes
        and then Name.Kind not in Libadalang.Common.Ada_Base_Id
                   | Libadalang.Common.Ada_Dotted_Name
      then
         return Name.As_Ada_Node;
      elsif Name.Kind not in Libadalang.Common.Ada_Name then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      Decl := Name.As_Name.P_Referenced_Decl;
      if Is_Null (Decl) then
         return Libadalang.Analysis.No_Ada_Node;
      elsif Decl.Kind = Libadalang.Common.Ada_Object_Decl
        and then not Is_Null (Decl.As_Object_Decl.F_Renaming_Clause)
      then
         return Ultimate_Alias
           (Decl.As_Object_Decl.F_Renaming_Clause.F_Renamed_Object,
            All_Nodes, Strip_Component);
      elsif Strip_Component
        and then Decl.Kind = Libadalang.Common.Ada_Component_Decl
        and then Name.Kind = Libadalang.Common.Ada_Dotted_Name
      then
         return Ultimate_Alias
           (Name.As_Dotted_Name.F_Prefix, All_Nodes, Strip_Component);
      end if;
      return Decl.As_Ada_Node;
   end Ultimate_Alias;

   --  An address specification: the object it applies to and the address
   --  expression, for both the aspect and the clause form.
   procedure Get_Address_Specification
     (Item    : Libadalang.Analysis.Ada_Node'Class;
      Object  : out Node;
      Address : out Node)
   is
      Current : Node;
   begin
      Object := Libadalang.Analysis.No_Ada_Node;
      Address := Libadalang.Analysis.No_Ada_Node;

      if Item.Kind = Libadalang.Common.Ada_Aspect_Assoc then
         if Canonical_Text (Item.As_Aspect_Assoc.F_Id) /= "address"
           or else Item.As_Aspect_Assoc.F_Id.Kind /=
                     Libadalang.Common.Ada_Identifier
         then
            return;
         end if;

         Current := Item.Parent;
         for Level in 1 .. 3 loop
            exit when Is_Null (Current);
            if Current.Kind in Libadalang.Common.Ada_Object_Decl_Range then
               Object := Current;
               Address := Item.As_Aspect_Assoc.F_Expr.As_Ada_Node;
               return;
            end if;
            Current := Current.Parent;
         end loop;
      elsif Is_Attribute
              (Item.As_Attribute_Def_Clause.F_Attribute_Expr, "address")
      then
         declare
            Decl : constant Libadalang.Analysis.Basic_Decl :=
              Item.As_Attribute_Def_Clause.F_Attribute_Expr.As_Attribute_Ref
                .F_Prefix.P_Referenced_Decl;
         begin
            if not Is_Null (Decl) then
               Object := Decl.As_Ada_Node;
               Address := Item.As_Attribute_Def_Clause.F_Expr.As_Ada_Node;
            end if;
         end;
      end if;
   end Get_Address_Specification;

   --  The four overlay checks, on an address aspect or clause.
   procedure Analyze_Address_Specification
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Object    : Node;
      Address   : Node;
      Overlaid  : Node := Libadalang.Analysis.No_Ada_Node;
      Named     : Node := Libadalang.Analysis.No_Ada_Node;
      Is_Overlay : Boolean;
   begin
      Get_Address_Specification (Item, Object, Address);
      if Is_Null (Object) or else Is_Null (Address) then
         return;
      end if;

      Is_Overlay := Is_Attribute (Address, "address");
      if Is_Overlay then
         Overlaid := Ultimate_Alias (Address.As_Attribute_Ref.F_Prefix);
         Named := Ultimate_Alias
           (Address.As_Attribute_Ref.F_Prefix, All_Nodes => False);
      end if;

      if On (Constant_Overlay)
        and then Is_Overlay
        and then Is_Constant_Object (Overlaid)
        and then (not Is_Constant_Object (Object)
                  or else Has_Aspect (Object, "Volatile")
                  or else Has_Aspect (Overlaid, "Volatile"))
      then
         Report_Finding
           (Unit, Item, Constant_Overlay,
            "non-constant object overlays a constant");
      end if;

      if On (Non_Constant_Overlay)
        and then Is_Overlay
        and then Is_Object (Overlaid)
        and then not Is_Constant_Object (Overlaid)
        and then (Is_Constant_Object (Object)
                  or else not Has_Aspect (Object, "Volatile")
                  or else (Overlaid.Kind /= Libadalang.Common.Ada_Param_Spec
                           and then Overlaid.Parent.Kind /=
                                      Libadalang.Common
                                        .Ada_Generic_Formal_Obj_Decl
                           and then not Has_Aspect (Overlaid, "Volatile")))
      then
         Report_Finding
           (Unit, Item, Non_Constant_Overlay,
            "constant or non-volatile object overlays a variable");
      end if;

      if Object.Kind not in Libadalang.Common.Ada_Object_Decl_Range then
         return;
      end if;

      if On (Nonoverlay_Address_Specification)
        and then not (Is_Overlay and then Is_Object (Named))
      then
         Report_Finding
           (Unit, Item, Nonoverlay_Address_Specification,
            "address specification is not an overlay of another object");
      end if;

      if On (Not_Imported_Overlay)
        and then Is_Overlay
        and then Is_Object (Named)
        and then not Has_Aspect (Object, "Import")
      then
         Report_Finding
           (Unit, Item, Not_Imported_Overlay,
            "overlaying object is not imported");
      end if;
   end Analyze_Address_Specification;

   function Has_Access_Type (Decl : Node) return Boolean is
      Type_Ref : Libadalang.Analysis.Type_Expr;
      Designated : Libadalang.Analysis.Base_Type_Decl;
   begin
      if Is_Null (Decl)
        or else Decl.Kind not in Libadalang.Common.Ada_Basic_Decl
      then
         return False;
      end if;

      Type_Ref := Decl.As_Basic_Decl.P_Type_Expression;
      if Is_Null (Type_Ref) then
         return False;
      end if;
      Designated := Type_Ref.P_Designated_Type_Decl;
      return not Is_Null (Designated) and then Designated.P_Is_Access_Type;
   end Has_Access_Type;

   function Is_Local_Object (Decl : Node) return Boolean
   is (not Is_Null (Decl)
       and then (Decl.Kind = Libadalang.Common.Ada_Param_Spec
                 or else (Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range
                          and then Has_Local_Scope (Decl))));

   --  True when Name denotes an object, or part of one, that is local to
   --  a subprogram, task, entry, protected body or block, without going
   --  through an access value.
   function Denotes_Local_Object
     (Name : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Kind : constant Node_Kind := Name.Kind;
   begin
      if Kind = Libadalang.Common.Ada_Qual_Expr then
         return Denotes_Local_Object (Name.As_Qual_Expr.F_Suffix);
      elsif Kind = Libadalang.Common.Ada_Paren_Expr then
         return Denotes_Local_Object (Name.As_Paren_Expr.F_Expr);
      elsif Kind = Libadalang.Common.Ada_Call_Expr then
         return Denotes_Local_Object (Name.As_Call_Expr.F_Name);
      elsif Kind in Libadalang.Common.Ada_Base_Id then
         return not Has_Access_Type
                      (Name.As_Name.P_Referenced_Decl.As_Ada_Node)
           and then Is_Local_Object
                      (Ultimate_Alias (Name, Strip_Component => True));
      elsif Kind /= Libadalang.Common.Ada_Dotted_Name then
         return False;
      end if;

      declare
         Prefix : constant Libadalang.Analysis.Name :=
           Name.As_Dotted_Name.F_Prefix;
         Owner  : constant Node := Prefix.P_Referenced_Decl.As_Ada_Node;
      begin
         if Is_Null (Owner) then
            return False;
         elsif Owner.Kind in Libadalang.Common.Ada_Basic_Subp_Decl
                 | Libadalang.Common.Ada_Subp_Body
                 | Libadalang.Common.Ada_Generic_Subp_Instantiation
         then
            return True;
         elsif Owner.Kind in Libadalang.Common.Ada_Base_Package_Decl
                 | Libadalang.Common.Ada_Package_Body
                 | Libadalang.Common.Ada_Generic_Package_Instantiation
         then
            return Has_Local_Scope (Owner)
              or else Denotes_Local_Object (Prefix);
         else
            return not Has_Access_Type (Owner)
              and then Denotes_Local_Object (Prefix);
         end if;
      end;
   end Denotes_Local_Object;

   --  Address_Of_Non_Volatile_Object and Access_To_Local_Object.
   procedure Analyze_Attribute
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Ref  : constant Libadalang.Analysis.Attribute_Ref :=
        Item.As_Attribute_Ref;
      Name : constant String := Canonical_Text (Ref.F_Attribute);
   begin
      if Name = "access" then
         if On (Access_To_Local_Object)
           and then Denotes_Local_Object (Ref.F_Prefix)
         then
            Report_Finding
              (Unit, Item, Access_To_Local_Object,
               "Access attribute applied to a local object");
         end if;
      elsif Name = "address"
        and then On (Address_Of_Non_Volatile_Object)
        and then not (Item.Parent.Kind =
                        Libadalang.Common.Ada_Attribute_Def_Clause
                      and then Item.Parent.As_Attribute_Def_Clause
                                 .F_Attribute_Expr.As_Ada_Node =
                               Item.As_Ada_Node)
      then
         declare
            Object : constant Node :=
              Ultimate_Alias (Ref.F_Prefix, All_Nodes => False);
         begin
            if not Is_Null (Object)
              and then Object.Kind in Libadalang.Common.Ada_Object_Decl_Range
              and then not Object.As_Object_Decl.F_Has_Constant.P_As_Bool
              and then not Has_Aspect (Object, "Volatile")
              and then not Has_Aspect (Object, "Atomic")
              and then not Has_Aspect (Object, "Shared")
            then
               Report_Finding
                 (Unit, Item, Address_Of_Non_Volatile_Object,
                  "Address attribute applied to a non-volatile object");
            end if;
         end;
      end if;
   end Analyze_Attribute;

   function Has_Component_Clause
     (Type_Decl : Libadalang.Analysis.Base_Type_Decl) return Boolean
   is
      Clause : constant Libadalang.Analysis.Record_Rep_Clause :=
        Type_Decl.P_Get_Record_Representation_Clause;
   begin
      if Is_Null (Clause) then
         return False;
      end if;

      for I in 1 .. Clause.F_Components.Children_Count loop
         if Clause.F_Components.Child (I).Kind =
              Libadalang.Common.Ada_Component_Clause
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Component_Clause;

   --  True when a component or discriminant below Item has a modular type.
   function Has_Modular_Component
     (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Type_Ref : Libadalang.Analysis.Type_Expr :=
        Libadalang.Analysis.No_Type_Expr;
   begin
      if Item.Kind = Libadalang.Common.Ada_Component_Def then
         Type_Ref := Item.As_Component_Def.F_Type_Expr;
      elsif Item.Kind = Libadalang.Common.Ada_Discriminant_Spec then
         Type_Ref := Item.As_Discriminant_Spec.F_Type_Expr;
      end if;

      if not Is_Null (Type_Ref) then
         declare
            Designated : constant Libadalang.Analysis.Base_Type_Decl :=
              Type_Ref.P_Designated_Type_Decl;
            Root       : Libadalang.Analysis.Base_Type_Decl;
         begin
            if not Is_Null (Designated) then
               Root := Designated.P_Root_Type;
               if not Is_Null (Root)
                 and then Root.Kind in Libadalang.Common.Ada_Type_Decl
                 and then not Is_Null (Root.As_Type_Decl.F_Type_Def)
                 and then Root.As_Type_Decl.F_Type_Def.Kind =
                            Libadalang.Common.Ada_Mod_Int_Type_Def
               then
                  return True;
               end if;
            end if;
         end;
      end if;

      for I in 1 .. Item.Children_Count loop
         if not Is_Null (Item.Child (I))
           and then Has_Modular_Component (Item.Child (I))
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Modular_Component;

   --  The three record-layout checks, on a type declaration.
   procedure Analyze_Record_Layout
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Decl : constant Libadalang.Analysis.Type_Decl := Item.As_Type_Decl;
      Def  : constant Libadalang.Analysis.Type_Def := Decl.F_Type_Def;
      Has_Clause : constant Boolean :=
        not Is_Null (Decl.P_Get_Record_Representation_Clause);
   begin
      if On (Incomplete_Representation_Specification)
        and then Has_Clause
        and then not (Has_Aspect (Decl, "Size")
                      and then Has_Aspect (Decl, "Pack"))
      then
         Report_Finding
           (Unit, Item, Incomplete_Representation_Specification,
            "record representation clause without both Size and Pack");
      end if;

      if Is_Null (Def)
        or else Def.Kind not in Libadalang.Common.Ada_Record_Type_Def
                  | Libadalang.Common.Ada_Derived_Type_Def
      then
         return;
      end if;

      if On (Bit_Record_Without_Layout)
        and then not Has_Clause
        and then Has_Aspect (Decl, "Pack")
        and then Has_Modular_Component (Item)
      then
         Report_Finding
           (Unit, Item, Bit_Record_Without_Layout,
            "packed record with modular components has no layout definition");
      end if;

      if On (No_Scalar_Storage_Order)
        and then not Has_Aspect (Decl, "Scalar_Storage_Order")
      then
         declare
            Parents   : constant Libadalang.Analysis.Base_Type_Decl_Array :=
              Decl.P_Base_Types;
            Inherited : Boolean := False;
            Laid_Out  : Boolean := Has_Component_Clause (Decl.As_Base_Type_Decl);
         begin
            for P of Parents loop
               if Def.Kind = Libadalang.Common.Ada_Derived_Type_Def
                 and then Has_Aspect (P, "Scalar_Storage_Order")
               then
                  Inherited := True;
               end if;
               Laid_Out := Laid_Out or else Has_Component_Clause (P);
            end loop;

            if Laid_Out and then not Inherited then
               Report_Finding
                 (Unit, Item, No_Scalar_Storage_Order,
                  "record with a layout does not specify "
                  & "Scalar_Storage_Order");
            end if;
         end;
      end if;
   end Analyze_Record_Layout;

   function Is_Representation_Pragma (Name : String) return Boolean
   is (Name = "atomic" or else Name = "atomic_components"
       or else Name = "independent" or else Name = "independent_components"
       or else Name = "pack" or else Name = "unchecked_union"
       or else Name = "volatile" or else Name = "volatile_components");

   --  The entity a representation item applies to, or a null node when
   --  Item is not a representation item.
   function Represented_Entity
     (Item : Libadalang.Analysis.Ada_Node'Class) return Node
   is
   begin
      case Item.Kind is
         when Libadalang.Common.Ada_Attribute_Def_Clause =>
            if Item.As_Attribute_Def_Clause.F_Attribute_Expr.Kind /=
                 Libadalang.Common.Ada_Attribute_Ref
            then
               return Libadalang.Analysis.No_Ada_Node;
            end if;
            return Item.As_Attribute_Def_Clause.F_Attribute_Expr
              .As_Attribute_Ref.F_Prefix.P_Referenced_Decl.As_Ada_Node;
         when Libadalang.Common.Ada_Enum_Rep_Clause =>
            return Item.As_Enum_Rep_Clause.F_Type_Name.P_Referenced_Decl
              .As_Ada_Node;
         when Libadalang.Common.Ada_Record_Rep_Clause =>
            return Item.As_Record_Rep_Clause.F_Name.P_Referenced_Decl
              .As_Ada_Node;
         when Libadalang.Common.Ada_At_Clause =>
            return Item.As_At_Clause.F_Name.P_Referenced_Decl.As_Ada_Node;
         when Libadalang.Common.Ada_Pragma_Node =>
            declare
               Entities : constant Libadalang.Analysis.Defining_Name_Array :=
                 Item.As_Pragma_Node.P_Associated_Entities;
            begin
               return (if Entities'Length = 0
                       then Libadalang.Analysis.No_Ada_Node
                       else Entities (Entities'First).P_Basic_Decl
                              .As_Ada_Node);
            end;
         when others =>
            return Libadalang.Analysis.No_Ada_Node;
      end case;
   end Represented_Entity;

   function Is_Representation_Item
     (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is (Item.Kind in Libadalang.Common.Ada_Enum_Rep_Clause
         | Libadalang.Common.Ada_Record_Rep_Clause
         | Libadalang.Common.Ada_At_Clause
       or else (Item.Kind = Libadalang.Common.Ada_Attribute_Def_Clause
                and then Item.As_Attribute_Def_Clause.F_Attribute_Expr.Kind =
                           Libadalang.Common.Ada_Attribute_Ref)
       or else (Item.Kind = Libadalang.Common.Ada_Pragma_Node
                and then Is_Representation_Pragma
                           (Canonical_Text (Item.As_Pragma_Node.F_Id))));

   --  True unless Item directly follows the declaration of Entity, with
   --  only other representation items of Entity in between.
   function Is_Misplaced
     (Item : Libadalang.Analysis.Ada_Node'Class; Entity : Node) return Boolean
   is
      Previous : constant Node := Item.Previous_Sibling;
   begin
      if Is_Null (Previous) then
         return True;
      elsif Is_Representation_Item (Previous) then
         return Represented_Entity (Previous) /= Entity
           or else Is_Misplaced (Previous, Entity);
      elsif Previous.Kind in Libadalang.Common.Ada_Basic_Decl then
         return Previous /= Entity;
      end if;
      return True;
   end Is_Misplaced;

   procedure Analyze_Placement
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Is_Representation_Item (Item)
        and then Is_Misplaced (Item, Represented_Entity (Item))
      then
         Report_Finding
           (Unit, Item, Misplaced_Representation_Item,
            "representation item does not directly follow the declaration "
            & "it applies to");
      end if;
   end Analyze_Placement;

   --  The representation aspects Representation_Specification looks for.
   Address : aliased constant String := "Address";
   Alignment : aliased constant String := "Alignment";
   Size : aliased constant String := "Size";
   Component_Size : aliased constant String := "Component_Size";
   External_Tag : aliased constant String := "External_Tag";
   Asynchronous : aliased constant String := "Asynchronous";
   Convention : aliased constant String := "Convention";
   Import : aliased constant String := "Import";
   Export : aliased constant String := "Export";
   No_Return : aliased constant String := "No_Return";
   Atomic : aliased constant String := "Atomic";
   Atomic_Components : aliased constant String := "Atomic_Components";
   Discard_Names : aliased constant String := "Discard_Names";
   Independent : aliased constant String := "Independent";
   Independent_Components : aliased constant String := "Independent_Components";
   Pack : aliased constant String := "Pack";
   Unchecked_Union : aliased constant String := "Unchecked_Union";
   Volatile : aliased constant String := "Volatile";
   Volatile_Components : aliased constant String := "Volatile_Components";

   --  True when Decl carries one of the representation aspects, by aspect,
   --  pragma or clause, on a name that has no earlier declaration.
   function Has_Representation_Aspect
     (Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
      type Text_Access is access constant String;
      Names : constant array (Positive range <>) of Text_Access :=
        (Address'Access, Alignment'Access, Size'Access,
         Component_Size'Access, External_Tag'Access, Asynchronous'Access,
         Convention'Access, Import'Access, Export'Access, No_Return'Access,
         Atomic'Access, Atomic_Components'Access, Discard_Names'Access,
         Independent'Access, Independent_Components'Access, Pack'Access,
         Unchecked_Union'Access, Volatile'Access,
         Volatile_Components'Access);
   begin
      for Defined of Decl.P_Defining_Names loop
         if not Is_Null (Defined)
           and then Is_Null (Defined.P_Previous_Part)
         then
            for Name of Names loop
               declare
                  Found : constant Libadalang.Analysis.Aspect :=
                    Defined.P_Get_Aspect (Aspect_Name (Name.all));
               begin
                  if Libadalang.Analysis.Exists (Found)
                    and then not Libadalang.Analysis.Inherited (Found)
                  then
                     return True;
                  end if;
               end;
            end loop;
         end if;
      end loop;
      return False;
   end Has_Representation_Aspect;

   procedure Analyze_Representation_Aspects
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if not Is_Set (Representation_Specification, "record_rep_clauses_only")
        and then Has_Representation_Aspect (Item.As_Basic_Decl)
      then
         Adalang_Analyzer.Report.Report_Rule_Violation
           (Unit, Item, Representation_Specification,
            "declaration has a representation aspect");
      end if;
   end Analyze_Representation_Aspects;

   --  True when Decl is an instantiation of Ada.Unchecked_Conversion,
   --  directly or through a subprogram renaming.
   function Is_Unchecked_Conversion (Decl : Node) return Boolean is
      Current : Node := Decl;
   begin
      for Step in 1 .. 8 loop
         exit when Is_Null (Current)
           or else Current.Kind /= Libadalang.Common.Ada_Subp_Renaming_Decl;
         Current := Current.As_Subp_Renaming_Decl.F_Renames.F_Renamed_Object
           .P_Referenced_Decl.As_Ada_Node;
      end loop;

      if Is_Null (Current)
        or else Current.Kind /=
                  Libadalang.Common.Ada_Generic_Subp_Instantiation
      then
         return False;
      end if;

      declare
         Generic_Name : constant Libadalang.Analysis.Name :=
           Current.As_Generic_Subp_Instantiation.F_Generic_Subp_Name;
         Written      : constant String := Canonical_Text (Generic_Name);
      begin
         if Written = "ada.unchecked_conversion" then
            return True;
         end if;

         declare
            Full_Name : constant String := Lower
              (Langkit_Support.Text.To_UTF8
                 (Generic_Name.P_Referenced_Decl
                    .P_Canonical_Fully_Qualified_Name));
         begin
            return Full_Name = "ada.unchecked_conversion"
              or else Full_Name = "unchecked_conversion";
         end;
      end;
   end Is_Unchecked_Conversion;

   function Is_Call_Context (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Call_Stmt
         | Libadalang.Common.Ada_Subp_Spec);

   procedure Analyze_Conversion_Call
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Has_Ancestor (Item, Is_Call_Context'Access)
        and then Is_Unchecked_Conversion
                   (Item.As_Call_Expr.P_Referenced_Decl.As_Ada_Node)
      then
         Report_Finding
           (Unit, Item, Unchecked_Conversion_As_Actual,
            "instance of Unchecked_Conversion used as an actual parameter "
            & "or default value");
      end if;
   end Analyze_Conversion_Call;

   function Is_System_Address
     (Actual : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Actual.As_Param_Assoc.F_R_Expr.As_Name.P_Referenced_Decl;
      Root : Libadalang.Analysis.Base_Type_Decl;
   begin
      if Is_Null (Decl)
        or else Decl.Kind not in Libadalang.Common.Ada_Base_Type_Decl
      then
         return False;
      end if;

      Root := Decl.As_Base_Type_Decl.P_Root_Type;
      if not Is_Null (Root) and then Root.P_Is_Private then
         Root := Root.P_Full_View.P_Root_Type;
      end if;
      return not Is_Null (Root)
        and then Lower
                   (Langkit_Support.Text.To_UTF8
                      (Root.P_Fully_Qualified_Name)) = "system.address";
   end Is_System_Address;

   procedure Analyze_Conversion_Instance
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Params : constant Libadalang.Analysis.Assoc_List :=
        Item.As_Generic_Subp_Instantiation.F_Params;
      Source : Node;
      Target : Node;
   begin
      if Params.Children_Count /= 2
        or else not Is_Unchecked_Conversion (Item.As_Ada_Node)
      then
         return;
      end if;

      if Is_Null (Params.Child (1).As_Param_Assoc.F_Designator)
        or else Canonical_Text (Params.Child (1).As_Param_Assoc.F_Designator)
                = "source"
      then
         Source := Params.Child (1);
         Target := Params.Child (2);
      else
         Source := Params.Child (2);
         Target := Params.Child (1);
      end if;

      if Is_Set (Unchecked_Address_Conversion, "all") then
         if not (Is_System_Address (Source)
                 or else Is_System_Address (Target))
         then
            return;
         end if;
      else
         declare
            Target_Decl : constant Libadalang.Analysis.Basic_Decl :=
              Target.As_Param_Assoc.F_R_Expr.As_Name.P_Referenced_Decl;
         begin
            if Is_Null (Target_Decl)
              or else Target_Decl.Kind not in
                        Libadalang.Common.Ada_Base_Type_Decl
              or else not Target_Decl.As_Base_Type_Decl.P_Full_View
                            .P_Is_Access_Type
              or else not Is_System_Address (Source)
            then
               return;
            end if;
         end;
      end if;

      Report_Finding
        (Unit, Item, Unchecked_Address_Conversion,
         "unchecked conversion from an address to an access value");
   end Analyze_Conversion_Instance;

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Node.Kind;
   begin
      Guarded
        (Unit, Node, On (Misplaced_Representation_Item),
         Analyze_Placement'Access);

      if Kind in Libadalang.Common.Ada_Aspect_Assoc
           | Libadalang.Common.Ada_Attribute_Def_Clause
      then
         Guarded
           (Unit, Node,
            On (Constant_Overlay) or else On (Non_Constant_Overlay)
            or else On (Nonoverlay_Address_Specification)
            or else On (Not_Imported_Overlay),
            Analyze_Address_Specification'Access);
      elsif Kind = Libadalang.Common.Ada_Attribute_Ref then
         Guarded
           (Unit, Node,
            On (Address_Of_Non_Volatile_Object)
            or else On (Access_To_Local_Object),
            Analyze_Attribute'Access);
      elsif Kind = Libadalang.Common.Ada_Call_Expr then
         Guarded
           (Unit, Node, On (Unchecked_Conversion_As_Actual),
            Analyze_Conversion_Call'Access);
      elsif Kind = Libadalang.Common.Ada_Generic_Subp_Instantiation then
         Guarded
           (Unit, Node, On (Unchecked_Address_Conversion),
            Analyze_Conversion_Instance'Access);
      elsif Kind in Libadalang.Common.Ada_Type_Decl then
         Guarded
           (Unit, Node,
            On (Bit_Record_Without_Layout) or else On (No_Scalar_Storage_Order)
            or else On (Incomplete_Representation_Specification),
            Analyze_Record_Layout'Access);
      end if;

      if On (Representation_Specification) then
         if Kind = Libadalang.Common.Ada_Record_Rep_Clause
           or else (Kind = Libadalang.Common.Ada_Enum_Rep_Clause
                    and then not Is_Set
                                   (Representation_Specification,
                                    "record_rep_clauses_only"))
         then
            Adalang_Analyzer.Report.Report_Rule_Violation
              (Unit, Node, Representation_Specification,
               "representation clause used");
         elsif Kind in Libadalang.Common.Ada_Basic_Decl then
            Guarded (Unit, Node, True, Analyze_Representation_Aspects'Access);
         end if;
      end if;
   end Analyze_Node;

end Adalang_Analyzer.Checks.Representation;

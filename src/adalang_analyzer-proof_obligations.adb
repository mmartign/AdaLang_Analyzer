--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Vectors;
with Interfaces;

with Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;

package body Adalang_Analyzer.Proof_Obligations is

   package Obligation_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Obligation);

   Obligations : Obligation_Vectors.Vector;

   function Create
     (Stable_Id          : String;
      Kind               : Obligation_Kind;
      Status             : Obligation_Status;
      Method             : Analysis_Method;
      Filename           : String := "";
      Line               : Natural := 0;
      Column             : Natural := 0;
      Operation          : String := "";
      Assumptions        : String := "";
      Abstract_State     : String := "";
      Explanation        : String := "";
      Imprecision_Source : String := "";
      Configuration_Id   : String := "") return Obligation
   is
   begin
      if Stable_Id = "" then
         raise Constraint_Error with "proof obligation ID must not be empty";
      end if;

      return
        (Stable_Id          => To_Unbounded_String (Stable_Id),
         Kind               => Kind,
         Location           =>
           (Filename => To_Unbounded_String (Filename),
            Line     => Line,
            Column   => Column),
         Status             => Status,
         Method             => Method,
         Operation          => To_Unbounded_String (Operation),
         Assumptions        => To_Unbounded_String (Assumptions),
         Abstract_State     => To_Unbounded_String (Abstract_State),
         Explanation        => To_Unbounded_String (Explanation),
         Imprecision_Source => To_Unbounded_String (Imprecision_Source),
         Configuration_Id   => To_Unbounded_String (Configuration_Id));
   end Create;

   function Kind_Name (Kind : Obligation_Kind) return String is
   begin
      case Kind is
         when Division_By_Zero_Check =>
            return "division-by-zero";
         when Integer_Overflow_Check =>
            return "integer-overflow";
         when Range_Check =>
            return "range-check";
         when Index_Check =>
            return "index-check";
         when Discriminant_Check =>
            return "discriminant-check";
         when Initialization_Check =>
            return "initialization-check";
         when Assertion_Check =>
            return "assertion";
         when Precondition_Check =>
            return "precondition";
         when Postcondition_Check =>
            return "postcondition";
         when Loop_Invariant_Initialization =>
            return "loop-invariant-initialization";
         when Loop_Invariant_Preservation =>
            return "loop-invariant-preservation";
         when Loop_Variant_Check =>
            return "loop-variant";
      end case;
   end Kind_Name;

   function Status_Name (Status : Obligation_Status) return String is
   begin
      case Status is
         when Proved_Safe =>
            return "proved-safe";
         when Definite_Error =>
            return "definite-error";
         when Unproved =>
            return "unproved";
         when Unreachable =>
            return "unreachable";
         when Unsupported =>
            return "unsupported";
      end case;
   end Status_Name;

   function Method_Name (Method : Analysis_Method) return String is
   begin
      case Method is
         when No_Analysis =>
            return "none";
         when Static_Evaluation =>
            return "static-evaluation";
         when Flow_Analysis =>
            return "flow-analysis";
         when Abstract_Interpretation =>
            return "abstract-interpretation";
         when Contract_Transfer =>
            return "contract-transfer";
         when External_Prover =>
            return "external-prover";
      end case;
   end Method_Name;

   function Scope_Description return String is
   begin
      if Adalang_Analyzer.Config.Verification_Mode then
         return
           "bounded scalar verification; unsupported boundaries are explicit";
      else
         return "enumerated outcomes in current analysis scope; not exhaustive";
      end if;
   end Scope_Description;

   function Normalized_Path (Filename : String) return String is
      First : Integer := Filename'First;
      Value : String := Filename;
   begin
      for C of Value loop
         if C = '\' then
            C := '/';
         end if;
      end loop;

      while First + 1 <= Value'Last
        and then Value (First .. First + 1) = "./"
      loop
         First := First + 2;
      end loop;

      return
        (if First > Value'Last then ""
         else Value (First .. Value'Last));
   end Normalized_Path;

   function Hex_Digit (Value : Interfaces.Unsigned_64) return Character is
      Hex_Chars : constant String := "0123456789abcdef";
   begin
      return Hex_Chars (Natural (Value) + 1);
   end Hex_Digit;

   function Hash_64 (Value : String) return String is
      use type Interfaces.Unsigned_64;

      Hash   : Interfaces.Unsigned_64 := 16#CBF29CE484222325#;
      Prime  : constant Interfaces.Unsigned_64 := 16#100000001B3#;
      Result : String (1 .. 16);
      Work   : Interfaces.Unsigned_64;
   begin
      for C of Value loop
         Hash := (Hash xor Interfaces.Unsigned_64 (Character'Pos (C))) * Prime;
      end loop;

      Work := Hash;
      for Index in reverse Result'Range loop
         Result (Index) := Hex_Digit (Work and 16#F#);
         Work := Interfaces.Shift_Right (Work, 4);
      end loop;
      return Result;
   end Hash_64;

   function Stable_Id_For
     (Unit      : Libadalang.Analysis.Analysis_Unit;
      Node      : Libadalang.Analysis.Ada_Node'Class;
      Kind      : Obligation_Kind;
      Operation : String := "") return String
   is
      Separator : constant Character := Character'Val (0);
      Key       : constant String :=
        Normalized_Path (Unit.Get_Filename) & Separator &
        Kind_Name (Kind) & Separator &
        Natural'Image (Natural (Node.Sloc_Range.Start_Line)) & ":" &
        Natural'Image (Natural (Node.Sloc_Range.Start_Column)) & ":" &
        Natural'Image (Natural (Node.Sloc_Range.End_Line)) & ":" &
        Natural'Image (Natural (Node.Sloc_Range.End_Column)) & Separator &
        (if Operation = ""
         then Adalang_Analyzer.Ada_Text.Node_Text (Node)
         else Operation);
   begin
      return "proof/v1/" & Hash_64 (Key);
   end Stable_Id_For;

   procedure Register_At
     (Unit               : Libadalang.Analysis.Analysis_Unit;
      Node               : Libadalang.Analysis.Ada_Node'Class;
      Kind               : Obligation_Kind;
      Status             : Obligation_Status;
      Method             : Analysis_Method;
      Operation          : String := "";
      Assumptions        : String := "";
      Abstract_State     : String := "";
      Explanation        : String := "";
      Imprecision_Source : String := "";
      Configuration_Id   : String := "";
      Final              : Boolean := False)
   is
      Operation_Text : constant String :=
        (if Operation = ""
         then Adalang_Analyzer.Ada_Text.Node_Text (Node)
         else Operation);
      Id             : constant String :=
        Stable_Id_For (Unit, Node, Kind, Operation_Text);
      Existing       : constant Natural := Find (Id);

      function Replaces
        (Old_Status, New_Status : Obligation_Status) return Boolean
      is
      begin
         case Old_Status is
            when Unproved =>
               return New_Status /= Unproved;
            when Unreachable =>
               return New_Status not in Unproved | Unreachable;
            when Unsupported =>
               return New_Status = Definite_Error;
            when Proved_Safe =>
               return New_Status in Unreachable | Unsupported;
            when Definite_Error =>
               return New_Status = Unreachable;
         end case;
      end Replaces;
   begin
      if Existing /= 0 then
         declare
            Item : constant Obligation := Element (Existing);
         begin
            if Item.Kind /= Kind then
               raise Constraint_Error with
                 "conflicting kind for proof obligation ID: " & Id;
            elsif Item.Status = Status then
               return;
            elsif Final then
               Update_Result
                 (Stable_Id          => Id,
                  Status             => Status,
                  Method             => Method,
                  Abstract_State     => Abstract_State,
                  Explanation        => Explanation,
                  Imprecision_Source => Imprecision_Source);
               return;
            elsif (Item.Status = Proved_Safe and then Status = Definite_Error)
              or else
                (Item.Status = Definite_Error and then Status = Proved_Safe)
            then
               raise Constraint_Error with
                 "contradictory proof results for obligation ID: " & Id;
            elsif Replaces (Item.Status, Status) then
               Update_Result
                 (Stable_Id          => Id,
                  Status             => Status,
                  Method             => Method,
                  Abstract_State     => Abstract_State,
                  Explanation        => Explanation,
                  Imprecision_Source => Imprecision_Source);
               return;
            else
               return;
            end if;
         end;
      end if;

      Register
        (Create
           (Stable_Id          => Id,
            Kind               => Kind,
            Status             => Status,
            Method             => Method,
            Filename           => Unit.Get_Filename,
            Line               => Natural (Node.Sloc_Range.Start_Line),
            Column             => Natural (Node.Sloc_Range.Start_Column),
            Operation          => Operation_Text,
            Assumptions        => Assumptions,
            Abstract_State     => Abstract_State,
            Explanation        => Explanation,
            Imprecision_Source => Imprecision_Source,
            Configuration_Id   => Configuration_Id));
   end Register_At;

   procedure Reset is
   begin
      Obligations.Clear;
   end Reset;

   function Find (Stable_Id : String) return Natural is
   begin
      for Index in Obligations.First_Index .. Obligations.Last_Index loop
         if To_String (Obligations (Index).Stable_Id) = Stable_Id then
            return Index;
         end if;
      end loop;
      return 0;
   exception
      when Constraint_Error =>
         --  First_Index .. Last_Index raises for an empty vector.
         return 0;
   end Find;

   procedure Register (Item : Obligation) is
      Id : constant String := To_String (Item.Stable_Id);
   begin
      if Id = "" then
         raise Constraint_Error with "proof obligation ID must not be empty";
      elsif Find (Id) /= 0 then
         raise Constraint_Error with
           "duplicate proof obligation ID: " & Id;
      end if;

      Obligations.Append (Item);
   end Register;

   function Count return Natural is
     (Natural (Obligations.Length));

   function Count (Status : Obligation_Status) return Natural is
      Result : Natural := 0;
   begin
      for Item of Obligations loop
         if Item.Status = Status then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Count;

   function Element (Index : Positive) return Obligation is
   begin
      return Obligations.Element (Index);
   end Element;

   procedure Update_Result
     (Stable_Id          : String;
      Status             : Obligation_Status;
      Method             : Analysis_Method;
      Abstract_State     : String := "";
      Explanation        : String := "";
      Imprecision_Source : String := "")
   is
      Index : constant Natural := Find (Stable_Id);
      Item  : Obligation;
   begin
      if Index = 0 then
         raise Constraint_Error with
           "unknown proof obligation ID: " & Stable_Id;
      end if;

      Item := Obligations.Element (Index);
      Item.Status := Status;
      Item.Method := Method;
      Item.Abstract_State := To_Unbounded_String (Abstract_State);
      Item.Explanation := To_Unbounded_String (Explanation);
      Item.Imprecision_Source := To_Unbounded_String (Imprecision_Source);
      Obligations.Replace_Element (Index, Item);
   end Update_Result;

end Adalang_Analyzer.Proof_Obligations;

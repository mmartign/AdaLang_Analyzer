--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

with Adalang_Analyzer.Proof_Obligations;
use Adalang_Analyzer.Proof_Obligations;

procedure Proof_Obligations_Model_Test is

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Check;

   First : Obligation;
begin
   Reset;
   Check (Count = 0, "new registry is not empty");

   First := Create
     (Stable_Id          => "proof/v1/example.adb/10/7/division-by-zero",
      Kind               => Division_By_Zero_Check,
      Status             => Unproved,
      Method             => Abstract_Interpretation,
      Filename           => "example.adb",
      Line               => 10,
      Column             => 7,
      Operation          => "10 / Divisor",
      Assumptions        => "Divisor in -1 .. 1",
      Abstract_State     => "Divisor => [-1, 1]",
      Explanation        => "zero remains in the represented range",
      Imprecision_Source => "input has no precondition",
      Reason_Code        => "missing-static-bounds",
      Blocking_Expression => "Divisor'Range",
      Inline_Path        => "Outer -> Inner",
      Configuration_Id   => "config-1");
   Register (First);

   Check (Count = 1, "registered obligation was not counted");
   Check (Count (Unproved) = 1, "unproved count is incorrect");
   Check
     (Find ("proof/v1/example.adb/10/7/division-by-zero") = 1,
      "stable ID was not indexed");
   Check
     (To_String (Element (1).Location.Filename) = "example.adb"
      and then Element (1).Location.Line = 10
      and then Element (1).Location.Column = 7,
      "source position was not preserved");
   Check
     (To_String (Element (1).Reason_Code) = "missing-static-bounds"
      and then To_String (Element (1).Blocking_Expression) = "Divisor'Range"
      and then To_String (Element (1).Inline_Path) = "Outer -> Inner",
      "unsupported provenance was not preserved");

   Check
     (Kind_Name (Division_By_Zero_Check) = "division-by-zero"
      and then Status_Name (Proved_Safe) = "proved-safe"
      and then Method_Name (Abstract_Interpretation) =
        "abstract-interpretation",
      "stable serialized names changed");

   Update_Result
     (Stable_Id      => "proof/v1/example.adb/10/7/division-by-zero",
      Status         => Proved_Safe,
      Method         => Static_Evaluation,
      Abstract_State => "Divisor => [1, 1]",
      Explanation    => "the divisor is exactly one");
   Check (Count (Unproved) = 0, "old result remained counted");
   Check (Count (Proved_Safe) = 1, "updated result was not counted");
   Check
     (Element (1).Status = Proved_Safe
      and then Element (1).Kind = Division_By_Zero_Check
      and then To_String (Element (1).Operation) = "10 / Divisor"
      and then Element (1).Reason_Code = Null_Unbounded_String,
      "result update changed obligation identity or context");

   declare
      Rejected : Boolean := False;
   begin
      begin
         Register (First);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      Check (Rejected, "duplicate stable ID was accepted");
   end;

   declare
      Rejected : Boolean := False;
   begin
      begin
         First := Create
           (Stable_Id => "",
            Kind      => Assertion_Check,
            Status    => Unsupported,
            Method    => No_Analysis);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      Check (Rejected, "empty stable ID was accepted");
   end;

   declare
      Rejected : Boolean := False;
   begin
      begin
         Update_Result
           (Stable_Id => "missing",
            Status    => Unsupported,
            Method    => No_Analysis);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      Check (Rejected, "unknown stable ID was updated");
   end;

   Reset;
   Check (Count = 0, "reset did not clear the registry");

   Ada.Text_IO.Put_Line ("proof obligation model tests passed");
end Proof_Obligations_Model_Test;

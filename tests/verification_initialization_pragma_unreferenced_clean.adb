procedure Verification_Initialization_Pragma_Unreferenced_Clean is

   --  "Status" in "pragma Unreferenced (Status);" is never read at
   --  runtime: it merely names the declaration without inspecting its
   --  value. Initialization_Read_Required's climbing walk previously had
   --  no guard for this node shape (unlike Checks.Data_Flow's separate
   --  Uninitialized_Read walk, which already excluded it), so it fell
   --  through to "return True" and misclassified this as a definite read
   --  of Status before its real assignment two statements later.
   --  Observed in the wild in gnatcoll-core's GNATCOLL.OS.FS.Close and
   --  GNATCOLL.Plugins.Unload: "Status : int; pragma Unreferenced
   --  (Status); begin Status := C_Close (FD); end;" (FP-043).
   Status : Integer;
   pragma Unreferenced (Status);

begin
   Status := 0;
end Verification_Initialization_Pragma_Unreferenced_Clean;

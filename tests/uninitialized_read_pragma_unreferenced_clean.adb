procedure Uninitialized_Read_Pragma_Unreferenced_Clean is

   --  A pragma argument naming an entity ("Has_Succeed" in "pragma
   --  Unreferenced (Has_Succeed);") is never read at runtime: unlike an
   --  executable pragma such as Assert, Unreferenced is a pure compiler
   --  directive that merely names a declaration without ever inspecting
   --  its value. First_Access's generic child walk previously visited
   --  this identifier the same way it would any ordinary reference,
   --  misclassifying it as a read of Has_Succeed before its first real
   --  assignment. Observed in the wild in AdaCore/Certyflie's
   --  parameter.adb, immediately after Has_Succeed's own declaration.
   Has_Succeed : Boolean;
   pragma Unreferenced (Has_Succeed);

begin
   Has_Succeed := True;
end Uninitialized_Read_Pragma_Unreferenced_Clean;

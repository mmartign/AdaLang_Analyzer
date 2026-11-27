--  Precision regression for Uninitialized_Output (FP-185, libhwbase's
--  HW.File.Map): a function called for the initial value of an object
--  declared in the subprogram, or in a block of it, runs before the
--  statements and sets the out parameter it is given as an out actual.
procedure Precision_Uninitialized_Output_Declaration_Call_Clean is
   function C_Map (Addr : out Integer; Len : Integer) return Integer
   with Import, Convention => C, External_Name => "c_map";

   function Ada_Map (Addr : out Integer; Len : Integer) return Integer is
   begin
      Addr := Len;
      return 0;
   end Ada_Map;

   procedure Map_Imported (Addr : out Integer; Ok : out Boolean) is
      Ret : constant Integer := C_Map (Addr => Addr, Len => 4);
   begin
      Ok := Ret = 0;
   end Map_Imported;

   procedure Map_Ada (Addr : out Integer; Ok : out Boolean) is
      Ret : constant Integer := Ada_Map (Addr, 4) + 1;
   begin
      Ok := Ret = 1;
   end Map_Ada;

   procedure Map_Block (Addr : out Integer; Ok : out Boolean) is
   begin
      declare
         Ret : constant Integer := Ada_Map (Addr, 8);
      begin
         Ok := Ret = 0;
      end;
   end Map_Block;

   A : Integer;
   B : Boolean;
begin
   Map_Imported (A, B);
   Map_Ada (A, B);
   Map_Block (A, B);
end Precision_Uninitialized_Output_Declaration_Call_Clean;

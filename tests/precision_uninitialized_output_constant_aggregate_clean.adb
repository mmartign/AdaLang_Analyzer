--  The first statements cannot raise when they store an aggregate holding
--  a constant of the component's own subtype (System.Null_Address, of a
--  private type) or 0 in a Storage_Count, whose bounds depend on
--  Standard'Address_Size, nor when they are pragmas that check nothing:
--  the out parameters they set are set when the handler runs too
--  (Ironclad's Arch.Limine.Get_Kernel_Segments, FP-198).
with System;
with System.Storage_Elements; use System.Storage_Elements;
procedure Precision_Uninitialized_Output_Constant_Aggregate_Clean is
   type Segment is record
      Start     : System.Address;
      Length    : Storage_Count;
      Can_Write : Boolean;
   end record;
   type Segments is array (Natural range <>) of Segment;
   Limit : constant Natural := 4;

   procedure Get
     (S : out Segments; Count : out Natural; Max : out Natural) is
   begin
      pragma Style_Checks (Off);
      S :=
        [others =>
           (Start => System.Null_Address, Length => 0, Can_Write => False)];
      Count := 0;
      Max := Limit;
      Count := Count + S'Length;
   exception
      when Constraint_Error =>
         null;
   end Get;

   A    : Segments (1 .. 2);
   N, M : Natural;
begin
   Get (A, N, M);
end Precision_Uninitialized_Output_Constant_Aggregate_Clean;

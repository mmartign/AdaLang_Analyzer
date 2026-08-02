with Ada.Calendar;
procedure Uninitialized_Read_Positional_Forward_Clean is

   --  A protected operation with an out-mode formal typed Ada.Calendar.
   --  Time among its parameters: Libadalang's own per-actual resolution
   --  (P_Get_Params) can fail to classify a positional actual against
   --  this callee even though it is otherwise unambiguous (the same
   --  resolution fragility already documented for Uninitialized_Output's
   --  Statement_Writes_Parameter). Forwarding all four locals
   --  positionally must still count as writing every one of them.
   protected Waiter_Information is
      procedure Info
        (Size        : out Natural;
         Max_Size    : out Natural;
         Max_Size_DT : out Ada.Calendar.Time;
         Counter     : out Natural);
   private
      Size        : Positive := 1;
      Max_Size    : Positive := 1;
      Max_Size_DT : Ada.Calendar.Time := Ada.Calendar.Clock;
      Counter     : Natural := 0;
   end Waiter_Information;

   protected body Waiter_Information is
      procedure Info
        (Size        : out Natural;
         Max_Size    : out Natural;
         Max_Size_DT : out Ada.Calendar.Time;
         Counter     : out Natural) is
      begin
         Size        := Waiter_Information.Size - 1;
         Max_Size    := Waiter_Information.Max_Size - 1;
         Max_Size_DT := Waiter_Information.Max_Size_DT;
         Counter     := Waiter_Information.Counter;
      end Info;
   end Waiter_Information;

   S : Natural;
   M : Natural;
   D : Ada.Calendar.Time;
   C : Natural;
begin
   Waiter_Information.Info (S, M, D, C);
   if C = 0 then
      null;
   end if;
end Uninitialized_Read_Positional_Forward_Clean;

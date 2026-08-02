with Ada.Calendar;
procedure Uninitialized_Read_Positional_Forward_Guard is

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

   --  A genuinely uninitialized read via a positional actual, at the same
   --  resolution-fragile callee shape as the clean sibling, must still be
   --  flagged: only "C" is read here (never forwarded to Info at all), so
   --  the fallback must not spuriously credit it as written.
begin
   if C = 0 then
      null;
   end if;
   Waiter_Information.Info (S, M, D, C);
end Uninitialized_Read_Positional_Forward_Guard;

with Ada.Calendar;
procedure Uninitialized_Output_Named_Actual_Forward_Clean is

   --  A protected operation with an out-mode formal typed Ada.Calendar.Time
   --  among its parameters: Libadalang's own per-actual resolution
   --  (P_Get_Params) can fail to classify a named actual against this
   --  callee even though it is otherwise unambiguous (observed against a
   --  real AWS.Server.Push protected operation). The wrapper below
   --  forwards its own out parameters by name; each must still count as
   --  written.
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

   procedure Info
     (Size        : out Natural;
      Max_Size    : out Natural;
      Max_Size_DT : out Ada.Calendar.Time;
      Counter     : out Natural) is
   begin
      Waiter_Information.Info
        (Size        => Size,
         Max_Size    => Max_Size,
         Max_Size_DT => Max_Size_DT,
         Counter     => Counter);
   end Info;

begin
   null;
end Uninitialized_Output_Named_Actual_Forward_Clean;

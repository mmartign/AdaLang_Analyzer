with System;

--  Positive fixture for the restricted-construct, complexity, data-flow,
--  style, and expression checks added alongside the original rule set.
procedure New_Checks_Findings is

   Global : Integer := 0;

   Overlay : Integer;
   for Overlay'Address use System'To_Address (16#1000#);

   function Factorial (N : Integer) return Integer is
   begin
      if N <= 1 then
         return 1;
      else
         return N * Factorial (N - 1);
      end if;
   end Factorial;

   procedure Many_Returns (N : Integer) is
   begin
      if N = 1 then
         return;
      end if;
      if N = 2 then
         return;
      end if;
   end Many_Returns;

   procedure Wide_Params (A, B, C, D : Integer) is
   begin
      null;
   end Wide_Params;

   procedure Deeply_Nested (N : Integer) is
   begin
      if N > 0 then
         if N > 1 then
            if N > 2 then
               if N > 3 then
                  null;
               end if;
            end if;
         end if;
      end if;
   end Deeply_Nested;

   procedure Has_Unused_Variable is
      Unused : Integer := 1;
   begin
      null;
   end Has_Unused_Variable;

   procedure Has_Empty_If (N : Integer) is
   begin
      if N > 0 then
         null;
      end if;
   end Has_Empty_If;

   function Has_Unneeded_Else (N : Integer) return Integer is
   begin
      if N > 0 then
         return 1;
      else
         return 0;
      end if;
   end Has_Unneeded_Else;

   function Set_Global (N : Integer) return Integer is
   begin
      Global := N;
      return N;
   end Set_Global;

   Flag : Boolean := True;
begin
   Global := Factorial (3);
   Many_Returns (1);
   Wide_Params (1, 2, 3, 4);
   Deeply_Nested (5);
   Has_Unused_Variable;
   Has_Empty_If (1);
   Global := Has_Unneeded_Else (1);
   Global := Set_Global (2);

   if Flag = True then
      null;
   end if;

   if Flag and Flag then
      null;
   end if;

   --  This comment line is deliberately padded to exceed the test's line-length threshold.
   Global := Global + 1;   
end New_Checks_Findings;

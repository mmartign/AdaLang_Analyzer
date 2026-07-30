procedure Automotive_Runtime_Suppression_Findings is
   pragma Suppress (Range_Check);
   pragma Suppress_All;
   pragma Check_Policy (Overflow_Check, Ignore);
   pragma Check_Policy (Index_Check, Off);
begin
   null;
end Automotive_Runtime_Suppression_Findings;

package body Abstract_Ops_User with SPARK_Mode is
   procedure Use_It (C : out Natural) is
   begin
      P.Walk (1, 10, C);
   end Use_It;
end Abstract_Ops_User;

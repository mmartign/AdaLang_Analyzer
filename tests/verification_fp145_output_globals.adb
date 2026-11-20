package body Verification_FP145_Output_Globals with SPARK_Mode is

   procedure Init is
   begin
      X := 0;
   end Init;

   procedure Write_Then_Read is
   begin
      X := 1;
      X := X + 1;
   end Write_Then_Read;

   procedure Call_Then_Read is
   begin
      Init;
      X := X + 1;
   end Call_Then_Read;

   procedure Both_Branches_Then_Read (C : Boolean) is
   begin
      if C then
         X := 1;
      else
         Init;
      end if;
      X := X + 1;
   end Both_Branches_Then_Read;

   procedure Give (Value : out Integer) is
   begin
      Value := 2;
   end Give;

   procedure Out_Actual_Then_Read is
   begin
      Give (X);
      X := X + 1;
   end Out_Actual_Then_Read;

   procedure Read_Then_Write is
   begin
      X := X + 1;
   end Read_Then_Write;

   procedure Write_Under_Guard is
      Y : Integer := 0;
   begin
      if Y = 0 then
         X := 1;
      end if;
      Y := X;
      X := Y;
   end Write_Under_Guard;

   procedure Read_Only (Y : out Integer) is
   begin
      Y := X;
      X := 0;
   end Read_Only;

end Verification_FP145_Output_Globals;

package body Verification_Old with SPARK_Mode is

   procedure Inc (Y : in out Integer) is
   begin
      Y := Y + 1;
   end Inc;

   procedure Ok_Two (Two_X : in out Integer) is
   begin
      Inc (Two_X);
      Inc (Two_X);
   end Ok_Two;

   procedure Bad_Two (Bad_X : in out Integer) is
   begin
      Inc (Bad_X);
      Inc (Bad_X);
   end Bad_Two;

   procedure Bad_Unknown (Unknown_X : in out Integer) is
   begin
      Unknown (Unknown_X);
      if Unknown_X < Integer'Last then
         Inc (Unknown_X);
      end if;
   end Bad_Unknown;

   procedure Bad_Loop (Loop_X : in out Integer; N : Natural) is
   begin
      for I in 1 .. N loop
         Loop_X := Loop_X - 1;
      end loop;
   end Bad_Loop;

   procedure Ok_Kept (Kept_X : in out Integer; Y : Integer) is
   begin
      null;
   end Ok_Kept;

   procedure Bad_Kept (Moved_X : in out Integer) is
   begin
      null;
   end Bad_Kept;

   procedure Ok_In (In_X : Integer; Z : out Integer) is
   begin
      Z := In_X;
   end Ok_In;

   procedure Step (C : in out Inner) is
   begin
      null;
   end Step;

   procedure Bump (C : in out Inner) is
   begin
      C.Rate := (if C.Rate = 1 then 2 else 1);
   end Bump;

   procedure Step_With
     (C : in out Inner; Data : Bytes; Out_Data : out Byte_Array) is
   begin
      Out_Data := (Out_Data'Range => Data (Data'First));
   end Step_With;

   procedure Ok_Component (Ok_O : in out Outer) is
   begin
      Step (Ok_O.I);
      Ok_O.Len := 0;
   end Ok_Component;

   procedure Bad_Component (Bad_O : in out Outer) is
   begin
      Bump (Bad_O.I);
   end Bad_Component;

   procedure Ok_Assert (Assert_O : in out Outer) is
      R : constant Positive := Rate_Of (Assert_O.I);
   begin
      Step (Assert_O.I);
      pragma Assert (Rate_Of (Assert_O.I) = R);
      Bump (Assert_O.I);
      pragma Assert (Rate_Of (Assert_O.I) /= R);
   end Ok_Assert;

   procedure Ok_Parts (Parts_O : in out Outer) is
   begin
      Step_With (Parts_O.I, Parts_O.Data, Parts_O.Key (1 .. Width));
   end Ok_Parts;

end Verification_Old;

package body Verification_Dereferences with SPARK_Mode is

   --  A write through the access value, and one to another component of
   --  the object holding it, leave the access value as it was.
   procedure Ok_Write (Ok_W : in out Holder) is
   begin
      Ok_W.Buffer.all (Ok_W.Buffer'First) := 1;
      Ok_W.Marks (1) := 2;
      Ok_W.Count := Ok_W.Buffer (Ok_W.Buffer'Last);
   end Ok_Write;

   procedure Ok_Branch (Ok_B : in out Holder) is
   begin
      if Ok_B.Buffer /= null then
         Ok_B.Count := Ok_B.Buffer'Length;
      end if;
   end Ok_Branch;

   procedure Bad_Branch (Bad_B : in out Holder) is
   begin
      if Bad_B.Buffer /= null then
         Bad_B.Count := 0;
      end if;
      Bad_B.Count := Bad_B.Buffer'Length;
   end Bad_Branch;

   procedure Touch (T : in out Holder) is
   begin
      T.Count := 0;
   end Touch;

   procedure Bad_Call (Bad_K : in out Holder) is
   begin
      Touch (Bad_K);
      Bad_K.Count := Bad_K.Buffer'Length;
   end Bad_Call;

   procedure Bad_Moved (Bad_M : in out Holder; Moved : out Bytes_Ptr) is
   begin
      Moved := Bad_M.Buffer;
      Bad_M.Buffer := null;
      Bad_M.Count := Bad_M.Buffer'Length;
   end Bad_Moved;

   procedure Take (From : in out Holder; Taken : out Bytes_Ptr) is
   begin
      Taken := From.Buffer;
      From.Buffer := null;
   end Take;

   procedure Ok_Take (Ok_T : in out Holder; N : out Natural) is
      Taken : Bytes_Ptr;
   begin
      Take (Ok_T, Taken);
      N := Taken'Length;
      Ok_T.Buffer := Taken;
   end Ok_Take;

   --  The access value is in the element written.
   procedure Bad_Shelf (Bad_S : in out Shelf) is
   begin
      Bad_S.Items (1).Count := Bad_S.Items (1).View'First;
      Bad_S.Items (1) := (View => null, Count => 0);
      Bad_S.Items (1).Count := Bad_S.Items (1).View'Last;
   end Bad_Shelf;

end Verification_Dereferences;

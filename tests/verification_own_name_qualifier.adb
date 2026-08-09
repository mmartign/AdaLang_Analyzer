procedure Verification_Own_Name_Qualifier is

   type Wait_Counter_Type is mod 2 ** 8;

   protected Waiter_Information is
      procedure Info (Size : out Natural; Counter : out Wait_Counter_Type);
   private
      Size    : Natural := 1;
      Counter : Wait_Counter_Type := 0;
   end Waiter_Information;

   protected body Waiter_Information is

      --  "Info.Size" and "Info.Counter" use the enclosing procedure's own
      --  name ("Info") to qualify its own out parameters (Ada's general
      --  unit-name qualification, RM 8.3), disambiguating them from the
      --  protected object's same-named private components -- not a field
      --  access on some other object named "Info", since there is none.
      procedure Info (Size : out Natural; Counter : out Wait_Counter_Type) is
      begin
         Info.Size    := Waiter_Information.Size;
         Info.Counter := Waiter_Information.Counter;
      end Info;

   end Waiter_Information;

begin
   null;
end Verification_Own_Name_Qualifier;

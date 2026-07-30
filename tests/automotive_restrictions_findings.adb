with Ada.Unchecked_Deallocation;

procedure Automotive_Restrictions_Findings is
   type Int_Access is access all Integer;
   P : Int_Access := new Integer'(1);

   procedure Free is new Ada.Unchecked_Deallocation
     (Object => Integer, Name => Int_Access);

   task type Worker is
      entry Start;
   end Worker;

   task body Worker is
   begin
      select
         accept Start do
            requeue Start;
         end Start;
      or
         terminate;
      end select;
   end Worker;

   W : Worker;
   X : Integer := P.all;
begin
   abort W;

   select
      delay 0.01;
   then abort
      X := X + 1;
   end select;

   Free (P);
   W.Start;
end Automotive_Restrictions_Findings;

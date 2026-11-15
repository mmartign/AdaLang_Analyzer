package State_Latch with SPARK_Mode,
  Abstract_State => State, Initializes => State
is
   type T is (Locked, Unlocked);

   type Stamp is record
      Seconds : Natural;
   end record;

   function Is_Locked return Boolean with Global => State;
   function Now return Stamp with Global => State;
   function After (Left, Right : Stamp) return Boolean;

   procedure Lock with Global => (In_Out => State), Post => Is_Locked;
   procedure Relock with Global => (In_Out => State);

private

   Current : T := Unlocked with Part_Of => State;
   Clock   : Stamp := (Seconds => 0) with Part_Of => State;

   function Is_Locked return Boolean is (Current = Locked)
     with Refined_Global => Current;
   function Now return Stamp is (Clock)
     with Refined_Global => Clock;
   function After (Left, Right : Stamp) return Boolean is
     (Left.Seconds >= Right.Seconds);

end State_Latch;

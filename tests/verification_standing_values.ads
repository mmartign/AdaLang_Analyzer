--  Objects that hold a value wherever a subprogram reads them: a constant,
--  a generic formal object of mode "in", an "in" parameter, and the
--  parameter of a loop or of a quantified expression. Each is within its
--  subtype, and that is all that is known of it from here: a variable is
--  none of them, nor is a constant that another name may denote.
pragma SPARK_Mode (On);

package Verification_Standing_Values is

   type Index is range 0 .. 31;
   type Long_Index is range 0 .. 63;
   type Wide is new Long_Long_Integer;
   subtype Limb is Wide range 0 .. 1000;
   type Vec is array (Index) of Wide;

   Scale : constant := 38;
   Huge  : constant := 2**62;

   Ceiling : constant Positive;

   generic
      Width : Positive;
      Count : Natural;
      Level : in out Positive;
      with procedure Notify;
   package Sized is
      Bits   : constant Positive := Width;
      Spare  : constant Natural := Count;
      Shared : Positive := 1;

      function By_Constant (Value : Natural) return Natural;
      function By_Formal (Value : Natural) return Natural;
      function By_Local_Constant (Value : Natural) return Natural;
      function By_Natural_Constant (Value : Natural) return Natural;
      function By_Natural_Formal (Value : Natural) return Natural;
      function By_Variable (Value : Natural) return Natural;
      function By_Variable_Formal (Value : Natural) return Natural;

      procedure After_Notify (Items : in out Vec; Chosen : Index);
      procedure Marked (Items : in out Vec);
      procedure Lapped (Items : in out Vec);
      procedure Turned (Items : in out Vec);
   end Sized;

   function By_Deferred (Value : Natural) return Natural;
   function By_Aliased (Value : Natural) return Natural;

   function Total (Items : Vec) return Wide
     with Pre => (for all Each in Index => Items (Each) in Limb);

   procedure Clear_Up_To (Items : in out Vec; Last : Index);
   procedure Set_From (Items : in out Vec; First : Index);
   procedure Shifted (Items : in out Vec; Last : Index);
   procedure Beyond (Items : in out Vec; Bound : Long_Index);
   procedure Each_Round (Items : in out Vec);

   function Scaled (Left, Right : Limb) return Wide;
   function Overscaled (Left, Right : Limb) return Wide;

   function Fits (Room, Used : Natural) return Boolean is (Used <= Room);

   procedure Reserve (Room, Used, Extra : Natural; Sum : out Natural)
     with Pre => Fits (Room, Used)
                 and then Extra <= Natural'Last - Used
                 and then Used + Extra <= Room;

private

   Ceiling : constant Positive := 7;

end Verification_Standing_Values;

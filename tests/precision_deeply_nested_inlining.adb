procedure Precision_Deeply_Nested_Inlining (Value : in out Integer) is

   procedure L1 (I : in out Integer) with Inline;
   procedure L2 (I : in out Integer) with Inline;
   procedure L3 (I : in out Integer) with Inline;
   procedure L4 (I : in out Integer) with Inline;
   procedure L5 (I : in out Integer) with Inline;

   procedure L1 (I : in out Integer) is
   begin
      L2 (I);
   end L1;

   procedure L2 (I : in out Integer) is
   begin
      L3 (I);
   end L2;

   procedure L3 (I : in out Integer) is
   begin
      L4 (I);
   end L3;

   procedure L4 (I : in out Integer) is
   begin
      L5 (I);
   end L4;

   procedure L5 (I : in out Integer) is
   begin
      I := I + 1;
   end L5;

begin
   L1 (Value);
end Precision_Deeply_Nested_Inlining;

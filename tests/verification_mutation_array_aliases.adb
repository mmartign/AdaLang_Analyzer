package body Verification_Mutation_Array_Aliases is
   procedure Alias (Xa : in out Wides; Ya : in out Wides; K : Index;
                    S : out Small) is
   begin
      Ya (K) := 200;
      S := Xa (K);
   end Alias;

   procedure Volatile (Vc : Shared; K : Index; S : out Small) is
   begin
      S := Vc (K);
   end Volatile;

   procedure Alias_Store (Xb : in out Wides; Yb : in out Wides; K : Index;
                          S : out Small) is
   begin
      Xb (K) := 5;
      Yb (K) := 200;
      S := Xb (K);
   end Alias_Store;
end Verification_Mutation_Array_Aliases;

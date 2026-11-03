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
end Verification_Mutation_Array_Aliases;

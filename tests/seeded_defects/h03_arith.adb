procedure H03_Arith (X : Integer; Y : Integer; Sink : out Integer)
with Pre => X in -10 .. 10 and then Y in -3 .. 3
is
   type Byte is mod 256;
   type Tiny is mod 4;
   B : Byte := Byte (abs X);
   T : Tiny := Tiny (abs Y);
   Big : Integer := Integer'Last;
   Neg : Integer := Integer'First;
   L : Long_Long_Integer;
begin
   Sink := 10 / ((X rem 3) + 2);             --  BAD
   Sink := 10 / ((X rem 3) + 1);             --  BAD
   Sink := 10 / ((X mod 3) + 1);
   Sink := 10 / ((X mod (-3)) + 2);          --  BAD
   Sink := 10 / ((X / 4) + 2);               --  BAD
   Sink := 10 / ((X / 4) - 2);               --  BAD
   Sink := 10 / (X * Y + 30);                --  BAD
   Sink := 10 / (X * Y - 30);                --  BAD
   Sink := 10 / (abs X - 10);                --  BAD
   Sink := 10 / (abs X + 1);
   Sink := 10 / (-X + 10);                   --  BAD
   Sink := 10 / (X ** 2 - 100);              --  BAD
   Sink := 10 / (X ** 2 + 1);
   Sink := 10 / (Y ** 3 + 27);               --  BAD
   Sink := 10 / (X - Y - 13);                --  BAD
   Sink := 10 / (X + Y + 13);                --  BAD
   Sink := 10 / (Integer'Max (X, Y) + 3);    --  BAD
   Sink := 10 / (Integer'Min (X, Y) - 3);    --  BAD
   Sink := 10 / (if X > 0 then X else X + 10);        --  BAD
   Sink := 10 / (if X > 0 then X else 1 - X);
   Sink := 10 / (case Y is when 0 => 1, when others => Y - 1);  --  BAD
   B := 255;
   Sink := 10 / Integer (B + 1);             --  BAD
   B := 0;
   Sink := 10 / Integer (B - 1 - 255);       --  BAD
   B := 128;
   Sink := 10 / Integer (B * 2);             --  BAD
   B := 16;
   Sink := 10 / Integer (B ** 2);            --  BAD
   T := 3;
   Sink := 10 / Integer (T + 1);             --  BAD
   T := Tiny (abs Y);
   Sink := 10 / Integer (T + 1);             --  BAD
   Sink := 10 / Integer (-T + 1);            
   Sink := 10 / Integer (not T);             --  BAD
   B := Byte (abs X);
   Sink := 10 / Integer (B - 11);            
   Sink := 10 / Integer (B + 246);           --  BAD
   Sink := Big + (X - X);
   Sink := Big + abs Y;                      --  BAD:integer-overflow
   Sink := Neg - abs Y;                      --  BAD:integer-overflow
   Sink := -Neg;                             --  BAD:integer-overflow
   Sink := abs Neg;                          --  BAD:integer-overflow
   Sink := Neg / (-1);                       --  BAD:integer-overflow
   Sink := (Big + Y) - Y;
   Sink := Big * (Y - Y + 2);
   Sink := Big + Y;                          --  BAD:integer-overflow
   L := Long_Long_Integer (Big * 2);         --  BAD:integer-overflow
   L := Long_Long_Integer (Big) * 2;
   Sink := Integer (L - Long_Long_Integer (Big)); 
   Sink := Integer (L) + 0;                  --  BAD:range-check
   Sink := Integer (Long_Long_Integer (Neg) - 1) + 0;
   Sink := 100_000 * 100_000;                --  BAD:range-check
   Sink := 16#7FFF_FFFF# + 1;                --  BAD:range-check
   Sink := 10 / (1E1 - 10);                  --  BAD
   Sink := 10 / (2#1010# - 10);              --  BAD
   Sink := 10 / (16#A# - 10);                --  BAD
   Sink := 10 / (1_0 - 10);                  --  BAD
end H03_Arith;

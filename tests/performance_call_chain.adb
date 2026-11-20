package body Performance_Call_Chain is

   function Append (L : List; S : String) return List is
     (Count => L.Count + S'Length);

   function Switches return List is
     (Empty
        .Append ("-x01")
        .Append ("-x02")
        .Append ("-x03")
        .Append ("-x04")
        .Append ("-x05")
        .Append ("-x06")
        .Append ("-x07")
        .Append ("-x08")
        .Append ("-x09")
        .Append ("-x10")
        .Append ("-x11")
        .Append ("-x12")
        .Append ("-x13")
        .Append ("-x14")
        .Append ("-x15")
        .Append ("-x16")
        .Append ("-x17")
        .Append ("-x18")
        .Append ("-x19")
        .Append ("-x20")
        .Append ("-x21")
        .Append ("-x22")
        .Append ("-x23")
        .Append ("-x24")
        .Append ("-x25")
        .Append ("-x26")
        .Append ("-x27")
        .Append ("-x28")
        .Append ("-x29")
        .Append ("-x30"));

end Performance_Call_Chain;

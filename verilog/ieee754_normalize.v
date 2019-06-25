module ieee754_normalize (
    input [24:0] src,
    output [22:0] result,
    output [4:0] shifted
);

 // What we want is a layered shifter, where each layer (optionally) shifts the significand by a power of two.
 // At the end, the top-most bit is guaranteed to be 1 (assuming at least one incoming bit was 1)
 // though, we don't actually return this one bit

wire [24:0] layer_0 = src;

wire [24:0] layer_1 = layer_0[24:9]  == 0 ? { layer_0[8:0], 16'd0 } : layer_0;
wire [24:0] layer_2 = layer_1[24:17] == 0 ? { layer_1[16:0], 8'd0 } : layer_1;
wire [24:0] layer_3 = layer_2[24:21] == 0 ? { layer_2[20:0], 4'd0 } : layer_2;
wire [24:0] layer_4 = layer_3[24:23] == 0 ? { layer_3[22:0], 2'd0 } : layer_3;
wire [22:0] layer_5 = layer_4[24]    == 0 ? layer_4[22:0] : layer_4[23:1]; // Discard the explicit one bit from the top

assign result = layer_5;

// We also output the size of the shift
assign shifted = { layer_0[24:9] == 0, layer_1[24:17] == 0, layer_2[24:21] == 0, layer_3[24:23] == 0, layer_4[24] == 0 };

endmodule
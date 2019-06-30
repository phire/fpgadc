module ieee754_normalize (
    input [27:0] src,
    output [22:0] result,
    output [4:0] shifted
);

 // What we want is a layered shifter, where each layer (optionally) shifts the significand by a power of two.
 // At the end, the top-most bit is guaranteed to be 1 (assuming at least one incoming bit was 1)
 // though, we don't actually return this one bit

wire [27:0] layer_0 = src;

wire [27:0] layer_1 = layer_0[27:12] == 0 ? { layer_0[11:0], 16'd0 } : layer_0;
wire [27:0] layer_2 = layer_1[27:20] == 0 ? { layer_1[19:0], 8'd0 } : layer_1;
wire [27:0] layer_3 = layer_2[27:24] == 0 ? { layer_2[23:0], 4'd0 } : layer_2;
wire [27:0] layer_4 = layer_3[27:26] == 0 ? { layer_3[25:0], 2'd0 } : layer_3;
wire [22:0] layer_5 = layer_4[27]    == 0 ? layer_4[25:3] : layer_4[26:4]; // Discard the explicit one bit from the top

assign result = layer_5;

// We also output the size of the shift
assign shifted = { layer_0[27:12] == 0, // shifted by 2^16
                   layer_1[27:20] == 0, // shifted by 2^8
                   layer_2[27:24] == 0, // shifted by 2^4
                   layer_3[27:26] == 0, // shifted by 2^2
                   layer_4[27] == 0 };  // shifted by 2^1

endmodule

module ieee754_normalize (
    input [47:0] src,
    output [22:0] result,
    output [5:0] shifted
);

 // What we want is a layered shifter, where each layer (optionally) shifts the significand by a power of two.
 // At the end, the top-most bit is guaranteed to be 1 (assuming at least one incoming bit was 1)
 // though, we don't actually return this one bit

wire [47:0] layer_0 = src;

wire [47:0] layer_1 = layer_0[47:16] == 0 ? { layer_0[15:0], 32'd0 } : layer_0;
wire [47:0] layer_2 = layer_1[47:32] == 0 ? { layer_1[31:0], 16'd0 } : layer_1;
wire [47:0] layer_3 = layer_2[47:40] == 0 ? { layer_2[39:0], 8'd0 } : layer_2;
wire [47:0] layer_4 = layer_3[47:44] == 0 ? { layer_3[43:0], 4'd0 } : layer_3;
wire [47:0] layer_5 = layer_4[47:46] == 0 ? { layer_4[45:0], 2'd0 } : layer_4;

wire [22:0] layer_6 = layer_5[47]    == 0 ? layer_5[45:23] : layer_5[46:24]; // Discard the explicit one bit from the top

assign result = layer_6;

// We also output the size of the shift
assign shifted = { layer_0[47:16] == 0, // shifted by 2^32
                   layer_1[47:32] == 0, // shifted by 2^16
                   layer_2[47:40] == 0, // shifted by 2^8
                   layer_3[47:44] == 0, // shifted by 2^4
                   layer_4[47:46] == 0, // shifted by 2^2
                   layer_5[47] == 0};   // shifted by 2^1

endmodule
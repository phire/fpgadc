// SH4a manual indicates that Multiply and Accumulate costs the same as Multiply
// So we will just implement the full fused multiply and accumulate and disable
// addition when doing regular multiplications.

// Theoretically, we could use this same MAC for addition/substraction. But the
// documantion claims that the SH4a can do addition with just 3 cycles of latency
// (compared to 5 for MAC) which strongly indicates a separate addition pipeline

// TODO: Actually implement accumulate. Currently hard coded to adding zero.

module ieee754_mac
(
    input clk,
    input [31:0] src_a,
    input [31:0] src_b,
    input [31:0] src_c,
    input subtract,
    output reg [31:0] dest
);

/*************
 * Floating point multiply is actually quite easy.
 * You more or less multiply the two significands and add the two exponents.
 * The new significand might require normalization.
 */

// Extract the various fields we need
wire [7:0]  exponent_a = src_a[30:23];
wire [7:0]  exponent_b = src_b[30:23];
wire [22:0] significand_a = src_a[22:0];
wire [22:0] significand_b = src_b[22:0];
wire sign_a = src_a[31];
wire sign_b = src_b[31];

// TODO: normalize denormals
// TODO: preserve infinities

// TODO: normalize src_c

// calculate new exponent
wire [9:0] sum_exponent = ({2'd0, exponent_a} + {2'd0, exponent_b}) - 10'd127; // bit 9 will be underflow, bit 8 will be overflow


// Multiply significands (remembering the implicit one bit at bit 23)
wire [47:0] result = { 1'b1, significand_a } * { 1'b1, significand_b };

// TODO: accumulate src_c !!!

/*************
 * Normalization is the process of finding the top one bit and shifting the result so
 * this bit at bit 23 of output significand (which gets discarded)
 *
 * Thanks to the implicit one bits at bit 23 of both inputs, there are only two possible
 * locations for the top one bit: result[47] or result[46];
 */

wire needs_normalization = result[47];

// Shift significand if needed
wire [22:0] normalized_significand = needs_normalization ? result[46:24] : result[45:23];
// increment exponent if needed.
wire [9:0]  normalized_exponent = needs_normalization ? sum_exponent + 1 : sum_exponent;

wire overflow = normalized_exponent[8];
wire underflow = normalized_exponent[9];

wire [22:0] out_significand = underflow ? 23'h0 : (overflow ? 23'h7fffff : normalized_significand);
wire [7:0]  out_exponent = underflow ? 8'h0 : (overflow ? 8'hfe : normalized_exponent[7:0]);

wire out_sign = sign_a ^ sign_b;

always @(posedge clk) begin
    //$display("%b", result);
    //$display("%b", out_significand);
    dest <= { out_sign, out_exponent, out_significand };
end

endmodule
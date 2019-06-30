// 32 bit add/subtract

// Not really tested. Only rounds towards zero. Flushes denormals. Doesn't handle infinities

// known issues:
// * 0x7f521e35 + 0x7f7ac3f4 = 0x7fe67114 (expected 0x7f7fffff)
// * 0x0024e135 + 0x00bb13c1 = 0x00cd845b (expected 0x00dff4f6)
// * 0x656a3a39 - 0x07ecfb54 = 0x656a3a39 (expected 0x656a3a38)
// * 0x2d274378 - 0x65114598 = 0xe5114598 (expected 0xe5114597)

module ieee754_add (
    input clk,
    input [31:0] src_a,
    input [31:0] src_b,
    input subtract,
    output reg [31:0] dest
);

// Extract the various fields we need
wire [7:0]  exponent_a = src_a[30:23];
wire [7:0]  exponent_b = src_b[30:23];
wire [22:0] significand_a = src_a[22:0];
wire [22:0] significand_b = src_b[22:0];
wire sign_a = src_a[31];
wire sign_b = src_b[31];

wire do_substract = (sign_a ^ sign_b) ^ subtract;

/************
 * Step one: Normalize the two floats so each exponent is equal
 * shift the significand to match.
 *
 * To maximize precision, we right-shift the smaller significant. The lower bits of the
 * smaller significand will be lost. If the smaller exponent is more than 24 less than the
 * higher one, all the bits will be lost and the resulting operation will be equivalent to
 * adding zero.
 */

// Find the biggest exponent
wire b_bigger = exponent_b > exponent_a;

// Swap exponents if necessary
wire [7:0] bigger_exponent  = b_bigger ? exponent_b : exponent_a;
wire [7:0] smaller_exponent = b_bigger ? exponent_a : exponent_b;

// Calculate difference (will be between 0 and 256)
wire [7:0] difference = bigger_exponent - smaller_exponent;

// check for denormals
wire denormal_bigger = bigger_exponent != 0;
wire denormal_smaller = smaller_exponent != 0;

// Swap significands to match above
// At this point we also take the time to add the explicit 24th bit, which is always 1
// Unless it's a denormal. then it's 0

wire [23:0] bigger_significand = {denormal_bigger, b_bigger ? significand_b : significand_a};
wire [23:0] smaller_significand = {denormal_smaller, b_bigger ? significand_a : significand_b};

// Shift the smaller significant (This shifter is massive, the largest part of the step one)
wire [46:0] smaller_significand_shifted = {smaller_significand, 23'h0} >> difference;

// We need to pad out both significands to twice the size (47 bits) so that any carries from the
// lower bits of the smaller significand during a subtraction can be applied.
// If the shift is bigger than 23, then there is no way any of the bits in the smaller significand
// can effect the results.

wire [46:0] bigger_significand_padded = {bigger_significand, 23'h0};


/************
 * Step two: add or substract the significands
 */

// hint, when pipelining, the shifter from above can poke into this stage

wire [47:0] result = do_substract ?
    bigger_significand_padded - smaller_significand_shifted :
    bigger_significand_padded + smaller_significand_shifted;

/***********
 * Step three: Normalize the result
 *
 * We need to find the top one bit and shift out any excessive zeros.
 * This is easy for the addition case, bit 23 of the bigger significand is guarrenteed to be one,
 * so our top one bit will either be in bit 23 or bit 24 (only when the exponents are equal).
 *
 * But the subtraction case is a nightmare.
 * The top one bit could be in any bit from 0 to 23.
 */

wire [5:0] shifted;
wire [22:0] shifted_significand;
ieee754_normalize it (result, shifted_significand, shifted);

// Adjust exponent by the size of the shift. Clamp to zero
// If the shift size is 31, that means there were no one bits in the shift. Force to zero.
wire [8:0] temp_subtract = (bigger_exponent + 1) - { 3'b0, shifted };
wire zero = temp_subtract[8] | shifted == 63;
wire [7:0] out_exponent = zero ? 8'h0 :temp_subtract[7:0];

// flush denormals to zero
wire [22:0] out_significand = (out_exponent == 0) ? 23'h0 : shifted_significand;

// TODO: implement infinities

// TODO: check the math on this. I'm not 100% sure
wire out_sign = (!b_bigger & sign_a) | (b_bigger & !subtract & sign_b) | (b_bigger & subtract & !sign_b);

always @(posedge clk) begin
    //$display("  %b", bigger_significand);
    //$display("- %b >> %d", smaller_significand_shifted, difference);
    //$display("------------\n %b", result);
    dest <= { out_sign, out_exponent, out_significand };
end

endmodule
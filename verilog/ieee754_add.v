// 32 bit add/subtract

// Not really tested. Doesn't round "correctly"

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

// Swap significands to match above
// At this point we also take the time to add the explicit 24th bit, which is always 1
wire [23:0] bigger_significand = {1'b1, b_bigger ? significand_b : significand_a};
wire [23:0] smaller_significand = {1'b1, b_bigger ? significand_a : significand_b};

// Shift the smaller significant (This shifter is massive, the largest part of the step one)
wire [23:0] smaller_significand_shifted = smaller_significand >> difference;

/************
 * Step two: add or substract the significands
 */

// hint, when pipelining, the shifter from above can poke into this stage

wire [24:0] result= do_substract ?
    bigger_significand - smaller_significand_shifted :
    bigger_significand + smaller_significand_shifted;

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

wire [4:0] shifted;
wire [22:0] out_significand;
ieee754_normalize it (result, out_significand, shifted);

wire zero = shifted == 31; // If none of the bits were set, force to zero
wire [7:0] out_exponent = zero ? 8'h0 : (bigger_exponent + 1) - { 3'b000, shifted };

// TODO: check the math on this. I'm not 100% sure
wire out_sign = do_substract & b_bigger;

always @(posedge clk) begin
    dest <= { out_sign, out_exponent, out_significand };
end

endmodule
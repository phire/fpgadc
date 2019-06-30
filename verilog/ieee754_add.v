// 32 bit add/subtract

// Not really tested. Only rounds towards zero. Flushes denormals. Doesn't handle infinities

// known issues:
// * 0x7f521e35 + 0x7f7ac3f4 = 0x7fe67114 (expected 0x7f7fffff) - shouldn't this be infinity? why is it expecting max float?
// * 0x0024e135 + 0x00bb13c1 = 0x00cd845b (expected 0x00dff4f6) - do I have an underflow on subtraction somewhere?
// * 0x0dc7dca3 + 0x8df7120c = 0x0e68654b (expected 0x8cbcd5a4) - sign bit issues.

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
// Keep two extra bits as "guard" and "round"
wire [25:0] smaller_significand_shifted = {smaller_significand, 2'b0} >> difference;

// If any of the discarded bits are one, the sticky bit will be set.
wire [7:0] discarded_bits = difference >= 26 ? 26 : difference; // clamp
wire [23:0] test_shift = smaller_significand[23:0] << (26 - discarded_bits);
wire sticky_bit = test_shift != 0;

// We need some way of preserving the extra precision of the discarded bits.
// For accurate rounding. IEEE754 specifies two guard bits and a sticky bit which we
// will preserve on the smaller significand. The bigger significand gets padding bits.
// We need to match the IEEE754 spec if we want the same result.
// Even though we don't currently support anything other than truncate rounding, the sticky bit
// is important for matching the result.
wire [26:0] smaller_significand_guarded = {smaller_significand_shifted, sticky_bit};
wire [26:0] bigger_significand_guarded = {bigger_significand, 3'h0};

/************
 * Step two: add or substract the significands
 */

// hint, when pipelining, the shifter from above can poke into this stage

wire [27:0] result = do_substract ?
    bigger_significand_guarded - smaller_significand_guarded :
    bigger_significand_guarded + smaller_significand_guarded;

/***********
 * Step three: Normalize the result
 *
 * We need to find the top one bit and shift out any excessive zeros.
 * This is easy for the addition case, bit 23 of the bigger significand is guarrenteed to be one,
 * so our top one bit will either be in bit 23 or bit 24 (only when the exponents are equal).
 *
 * But the subtraction case is a nightmare.
 * The top one bit could be in any bit from 0 to 23 (or the guard bits)
 */

 // TODO: implement round to nearest mode using guard bits

wire [4:0] shifted;
wire [22:0] shifted_significand;
ieee754_normalize it (result, shifted_significand, shifted);

// Adjust exponent by the size of the shift. Clamp to zero
// If the shift size is 31, that means there were no one bits in the shift. Force to zero.
wire [8:0] temp_subtract = (bigger_exponent + 1) - { 3'b0, shifted };
wire zero = temp_subtract[8] | shifted == 31;
wire [7:0] out_exponent = zero ? 8'h0 :temp_subtract[7:0];

// flush denormals to zero
wire [22:0] out_significand = (out_exponent == 0) ? 23'h0 : shifted_significand;

// TODO: implement infinities

// TODO: check the math on this. I'm not 100% sure
//       Update, it's wrong. Doesn't correctly handle subtractions where numbers share an exponent.
wire out_sign = (!b_bigger & sign_a) | (b_bigger & !subtract & sign_b) | (b_bigger & subtract & !sign_b);

always @(posedge clk) begin
    //  $display("\n  %b        exp %d", bigger_significand_guarded, bigger_exponent);
    //  $display(" (%b)", smaller_significand);
    //  $display("%c %b >> %3d exp %d (%d)", do_substract ? "-" : "+", smaller_significand_guarded, difference, smaller_exponent, discarded_bits);
    //  $display("------------\n %b", result);
    dest <= { out_sign, out_exponent, out_significand };
end

endmodule
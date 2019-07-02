#include <stdlib.h>
#include <cfenv>
#include <cmath>
#include <limits>
#include <cstdint>
#include "Vieee754_mac.h"
#include "verilated.h"

Vieee754_mac *tb;

void tick() {
    tb->eval();
    tb->clk = 1;
    tb->eval();
    tb->clk = 0;
    tb->eval();
}

uint32_t hex(float f) {
    uint32_t ret;
    memcpy(&ret, &f, sizeof(float));
    return ret;
}

float ieee(uint32_t hex) {
    float ret;
    memcpy(&ret, &hex, sizeof(float));
    return ret;
}

// force inlining off, otherwise calculation of expected might use wrong rounding mode
void __attribute__ ((noinline)) mac(float a, float b, float c = 0.0f) {
    float expected = std::fmaf(a, b, c);

    // a standards compliant way to flush denormals to zero
    if (std::fpclassify( expected ) == FP_SUBNORMAL) {
        expected = copysignf(0.0f, expected);
    }

    tb->src_a = hex(a);
    tb->src_b = hex(b);
    tb->src_c = hex(c);
    tick();
    uint32_t out = tb->dest;
    printf("%g * %g + %g = %g | 0x%08x 0x%08x 0x%08x = 0x%08x", a, b, c, ieee(out), hex(a), hex(b), hex(c), out);
    if (hex(expected) != out) {
        printf(" (expected %g 0x%08x)\n",  expected, hex(expected));
        //exit(EXIT_FAILURE);
    }
    else {
        printf("\n");
    }
}

float randfloat() {
    // xor two rand()s together to make sure we get a full 32 random bits
    uint32_t hex = static_cast<uint32_t>(rand()) ^ (static_cast<uint32_t>(rand()) << 16);
    return ieee(hex);
}

int main(int argc, char **argv) {
    // Initialize Verilators variables
	Verilated::commandArgs(argc, argv);

	// Create an instance of our module under test
	tb = new Vieee754_mac;

    // Setup the round to zero rounding mode.
    #pragma STDC FENV_ACCESS ON
    std::fesetround(FE_TOWARDZERO);

    mac(std::numeric_limits<float>::min(), std::numeric_limits<float>::min());
    mac(1.0f, 1.0f);

    mac(1.0f, 2.0f);
    mac(1.0f, 2.0f);
    mac(0.5f, 0.5f);
    mac(3.0f, 0.1f);
    mac(3.0f, 300.0f);
    mac(1.0f, 0.5f);
    mac(1.0f, 0.999f);
    mac(1.0f, 0.999f);
    mac(1.00001f, 1.00001f);
    mac(1.0f, 2.0f);
    mac(std::numeric_limits<float>::denorm_min(), std::numeric_limits<float>::denorm_min());
    mac(0.0f, 3000.0f);
    mac(3000.0f, 0.0000000001f);
    mac(-0.0000000001f, 3000.0f);
    mac(-0.000001f, 3300000000.0f);

    mac(ieee(0x3f800000), ieee(0x3f800000-1));
    mac(ieee(0x3f800000), ieee(0x3f800000-3));


    srand(8);
    for (int i = 0; i < 10; i++) {
        float a = randfloat();
        float b = randfloat();
        float c = 0.0f;
        float expected = std::fmaf(a, b, c);
        printf("%d: ", i);
        if (!isinff(a) && !isinff(b) &&!isinff(expected) && !isnanf(a) && !isnanf(b) && !isnanf(expected)) { // Infinities and NaNs are currently unsupported.
            mac(a, b, c);
        }
    }

    return 0;
}
#include <stdlib.h>
#include <cfenv>
#include <cmath>
#include <limits>
#include <cstdint>
#include "Vieee754_add.h"
#include "verilated.h"

Vieee754_add *tb;

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
void __attribute__ ((noinline)) add(float a, float b, bool sub=false) {
    float expected = sub ? a - b : a + b;

    // a standards compliant way to flush denormals to zero
    if (std::fpclassify( expected ) == FP_SUBNORMAL) {
        expected = copysignf(0.0f, expected);
    }

    tb->src_a = hex(a);
    tb->src_b = hex(b);
    tb->subtract = sub ? 1 : 0;
    tick();
    uint32_t out = tb->dest;
    printf("%g %s %g = %g | 0x%08x %s 0x%08x = 0x%08x", a, sub ? "-" : "+", b, ieee(out), hex(a), sub ? "-" : "+", hex(b), out);
    if (hex(expected) != out) {
        printf(" (expected %g 0x%08x)\n",  expected, hex(expected));
        exit(EXIT_FAILURE);
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
	tb = new Vieee754_add;

    // Setup the round to zero rounding mode.
    #pragma STDC FENV_ACCESS ON
    std::fesetround(FE_TOWARDZERO);

    add(ieee(0x3f800000), ieee(0x3f800000-1), true);
    add(ieee(0x3f800000), ieee(0x3f800000-3), true);
    add(1.0f, 1.0f);

    add(1.0f, 2.0f);
    add(1.0f, 2.0f);
    add(0.5f, 0.5f);
    add(3.0f, 0.1f);
    add(3.0f, 300.0f);
    add(1.0f, 0.5f, true);
    add(1.0f, 0.999f);
    add(1.0f, 0.999f, true);
    add(1.0f, 1.0f, true);
    add(1.000001f, 1.000001f);
    add(1.0f, 2.0f, true);
    add(std::numeric_limits<float>::denorm_min(), std::numeric_limits<float>::denorm_min());
    add(0.0f, 3000.0f);
    add(3000.0f, 0.0000000001f, true);
    add(-0.0000000001f, 3000.0f);
    add(-0.000001f, 3300000000.0f);

    //add(ieee(0x7f521e35), ieee(0x7f7ac3f4), false); // Intel bug?
    //add(ieee(0x0024e135), ieee(0x00bb13c1), false);
    add(ieee(0x656a3a39), ieee(0x07ecfb54), true);
    add(ieee(0x2d274378), ieee(0x65114598), true);

    srand(8);
    for (int i = 0; i < 1000; i++) {
        float a = randfloat();
        float b = randfloat();
        bool op = (rand() & 1) == 0;
        float expected = op ? a - b : a + b;
        printf("%d: ", i);
        if (!isinff(a) && !isinff(b) &&!isinff(expected) && !isnanf(a) && !isnanf(b) && !isnanf(expected)) { // Infinities and NaNs are currently unsupported.
            add(a, b, op);
        }
    }

    return 0;
}
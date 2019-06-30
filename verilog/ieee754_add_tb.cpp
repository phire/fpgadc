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
    printf("%f %s %f = %f | 0x%08x %s 0x%08x = 0x%08x", a, sub ? "-" : "+", b, ieee(out), hex(a), sub ? "-" : "+", hex(b), out);
    if (hex(expected) != out) {
        printf(" (expected %f 0x%08x)\n",  expected, hex(expected));
        exit(EXIT_FAILURE);
    }
    else {
        printf("\n");
    }
}

int main(int argc, char **argv) {
    // Initialize Verilators variables
	Verilated::commandArgs(argc, argv);

	// Create an instance of our module under test
	tb = new Vieee754_add;

    // Setup the round to zero rounding mode.
    #pragma STDC FENV_ACCESS ON
    std::fesetround(FE_TOWARDZERO);

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

    srand(8);
    for (int i = 0; i < 1000; i++) {
        float a = ieee(rand());
        float b = ieee(rand()); // Fixme: rand only goes upto MAX_INT, so all our numbers are positive.
        printf("%d: ", i);
        if (!isinff(a) && !isinff(b) &&!isinff(a+b) && !isnanf(a) && !isnanf(b) && !isnanf(a+b)) { // Infinities and NaNs are currently unsupported.
            add(a, b, true);
        }
    }

    return 0;
}
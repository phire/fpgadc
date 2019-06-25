#include <stdlib.h>
#include "Vieee754_add.h"
#include "verilated.h"

Vieee754_add *tb;

void tick() {
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

void add(float a, float b, float expected, bool sub=false) {
    tb->src_a = hex(a);
    tb->src_b = hex(b);
    tb->subtract = sub ? 1 : 0;
    tick();
    tick();
    uint32_t out = tb->dest;
    printf("%f %s %f = %f 0x%08x", a, sub ? "-" : "+", b, ieee(out), out);
    if (hex(expected) != out) {
        printf(" (expected %f 0x%08x)\n",  expected, hex(expected));
        //exit(EXIT_FAILURE);
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

    add(1.0f, 1.0f, 2.0f);

    add(1.0f, 2.0f, 3.0f);
    add(1.0f, 2.0f, 3.0f);
    add(0.5f, 0.5f, 1.0f);
    add(3.0f, 0.1f, 3.1f);
    add(3.0f, 300.0f, 303.0f);
    add(1.0f, 0.5f, 0.5f, true);
    add(1.0f, 0.999f, 1.999f);
    add(1.0f, 0.999f, 1.0f - 0.999f, true);
    add(1.0f, 1.0f, 0.0f, true);
    add(1.000001f, 1.000001f, 2.000002f);
    add(1.0f, 2.0f, -1.0f, true);

    exit(EXIT_SUCCESS);
}
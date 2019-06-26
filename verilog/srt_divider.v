module srt_divider
#(parameter SIZE=23)
(
    input clk,
    input [SIZE:0] divisor,
    input [SIZE:0] dividend,
    input start,
    output [SIZE:0] result,
    output reg done
);

reg [SIZE:0] remainder;
reg [SIZE:0] qpos;
reg [SIZE:0] qneg;
reg [7:0] count;

reg [2:0] quotient; // Can be one of: -2, -1, 0, 1, 2
wire [SIZE+1:0] multiple = quotient[1:0] == 0
                        ? 25'b0
                        : (quotient[0] ? {1'b0, divisor} : {divisor, 1'b0} );

wire [7:0] r8 = remainder[SIZE:SIZE-7];
wire [7:0] m8 = multiple[SIZE+1:SIZE-6];
wire [7:0] guess = quotient[2] ? r8 + m8 : r8 - m8 - 1;

wire [SIZE+1:0] new_remainder = quotient[2] ? remainder + multiple : remainder - multiple;

always @(posedge clk) begin
    if (start) begin
        remainder <= dividend;
        done <= 0;
        count <= 0;
        $display("start");
    end
    else if (done == 0) begin
        remainder <= (new_remainder << 2);
        qpos <= { qpos[SIZE-2:0], quotient[2] ? 2'b00 : quotient[1:0] };
        qneg <= { qneg[SIZE-2:0], quotient[2] ? quotient[1:0] : 2'b00 };
        count <= count + 2;
        done <= count >= SIZE;
    end
    else begin
        $display("done %b", result);
    end
    $display("%d: remainder: %b guess = %b q = %b - qpos %b qneg %b", count, remainder, guess, quotient, qpos, qneg);
end

always @(posedge clk) begin
    casez (guess)
        8'b111001??: quotient <= 3'b110;
        8'b111010??: quotient <= 3'b110;
        8'b111011??: quotient <= 3'b110;
        8'b11110000: quotient <= 3'b110;
        8'b11110001: quotient <= 3'b101;
        8'b11110010: quotient <= 3'b101;
        8'b11110011: quotient <= 3'b101;
        8'b111110??: quotient <= 3'b101;
        8'b111111??: quotient <= 3'b000;
        8'b000000??: quotient <= 3'b000;
        8'b000001??: quotient <= 3'b001;
        8'b000010??: quotient <= 3'b001;
        8'b000011??: quotient <= 3'b010;
        8'b000100??: quotient <= 3'b010;
        8'b000101??: quotient <= 3'b010;
        default: begin $display("error %b", guess); quotient <= 3'b000; end
    endcase
end

assign result = qpos - qneg;

endmodule
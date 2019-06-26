module srt_divider_tb ();

reg clk;
reg start;
wire done;
reg [23:0] a;
reg [23:0] b;
wire [23:0] result;

srt_divider DIV (clk, a, b, start, result, done);

initial begin
    a = 23'd1;
    b = 23'd127;
    start = 1;
    repeat(2) @(posedge clk);
    start = 0;
    repeat(14) @(posedge clk);
    $display("done %b, %d / %d = result %d", done, b, a, result >> 4);
    $finish;
end

initial begin
    clk = 1'b0;
    forever #10 clk = ~clk;
end

endmodule
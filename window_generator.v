`timescale 1ns/1ps
// ============================================================
// 3x3 Window Generator
// ============================================================
module window_generator(
    input clk,
    input rst_n,
    input [7:0] r0,
    input [7:0] r1,
    input [7:0] r2,
    input in_valid,
    output reg [7:0] win00, win01, win02,
    output reg [7:0] win10, win11, win12,
    output reg [7:0] win20, win21, win22
);
    reg [7:0] shift_reg0 [0:1];
    reg [7:0] shift_reg1 [0:1];
    reg [7:0] shift_reg2 [0:1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg0[0] <= 0;
            shift_reg0[1] <= 0;
            shift_reg1[0] <= 0;
            shift_reg1[1] <= 0;
            shift_reg2[0] <= 0;
            shift_reg2[1] <= 0;
            win00         <= 0;
            win01         <= 0;
            win02         <= 0;
            win10         <= 0;
            win11         <= 0;
            win12         <= 0;
            win20         <= 0;
            win21         <= 0;
            win22         <= 0;
        end else if (in_valid) begin
            // row 0
            shift_reg0[1] <= shift_reg0[0];
            shift_reg0[0] <= r0;
            win00         <= shift_reg0[1];
            win01         <= shift_reg0[0];
            win02         <= r0;

            // row 1
            shift_reg1[1] <= shift_reg1[0];
            shift_reg1[0] <= r1;
            win10         <= shift_reg1[1];
            win11         <= shift_reg1[0];
            win12         <= r1;

            // row 2
            shift_reg2[1] <= shift_reg2[0];
            shift_reg2[0] <= r2;
            win20         <= shift_reg2[1];
            win21         <= shift_reg2[0];
            win22         <= r2;
        end
    end
endmodule
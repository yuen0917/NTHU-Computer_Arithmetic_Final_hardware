`timescale 1ns/1ps
// ============================================================
// Line Buffer for 3x3 convolution
// ============================================================
module line_buffer #(
    parameter IMG_W   = 28,
    parameter PADDING =  1
)(
    input            clk,
    input            rst_n,
    input      [7:0] in_data,
    input            in_valid,
    output reg [7:0] out_row0,
    output reg [7:0] out_row1,
    output reg [7:0] out_row2
);
    localparam COL_CNT_W = $clog2(IMG_W);
    reg [7:0] buf1 [0:IMG_W - 1];
    reg [7:0] buf2 [0:IMG_W - 1];


    reg [COL_CNT_W-1:0] col_cnt;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(i = 0; i < IMG_W; i = i + 1) begin
                buf1[i] <= 0;
                buf2[i] <= 0;
            end
            col_cnt <= 0;
            out_row0 <= 0;
            out_row1 <= 0;
            out_row2 <= 0;
        end else if (in_valid) begin
            buf1[col_cnt] <= in_data;
            buf2[col_cnt] <= buf1[col_cnt];

            out_row2 <= in_data;
            out_row1 <= buf1[col_cnt];
            out_row0 <= buf2[col_cnt];

            if (col_cnt == IMG_W - 1)
                col_cnt <= 0;
            else
                col_cnt <= col_cnt + 1;
        end
    end
endmodule
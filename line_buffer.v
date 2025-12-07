`timescale 1ns/1ps
// ============================================================
// Line Buffer
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
    // [修正] 移除 TOTAL_W，只用 IMG_W。我們不需要在 buffer 內做 padding。
    // Padding 由 window generator 的邊界條件或 Top level 控制 (這裡簡化處理)

    reg [7:0] buf1 [0:IMG_W - 1];
    reg [7:0] buf2 [0:IMG_W - 1];

    // 計數器只需數到 27
    reg [$clog2(IMG_W)-1:0] col_cnt;

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
            // 1. 寫入 Buffer (存入當前列位置)
            buf1[col_cnt] <= in_data;
            buf2[col_cnt] <= buf1[col_cnt];

            // 2. 輸出 Buffer (讀取當前列位置的舊資料)
            // out_row2 是最新的資料 (直通)
            // out_row1 是上一行的資料 (從 buf1 讀)
            // out_row0 是上上行的資料 (從 buf2 讀)
            out_row2 <= in_data;
            out_row1 <= buf1[col_cnt];
            out_row0 <= buf2[col_cnt];

            // 3. 更新計數器 (0 ~ 27)
            if (col_cnt == IMG_W - 1)
                col_cnt <= 0;
            else
                col_cnt <= col_cnt + 1;
        end
    end
endmodule
// ------------------------------------------------------------
// Line Buffer for 3x3 window
// ------------------------------------------------------------
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
    localparam TOTAL_W   = IMG_W + 2 * PADDING;  // total width (including padding)    
    localparam CNT_WIDTH = $clog2(TOTAL_W);


    reg [7:0] buf1 [0:IMG_W - 1];
    reg [7:0] buf2 [0:IMG_W - 1];

    reg [CNT_WIDTH-1:0] col_cnt;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(i = 0; i < IMG_W; i = i + 1) begin
                buf1[i] <= 0;
                buf2[i] <= 0;
            end
            col_cnt <= 0;
        end else if (in_valid) begin
            out_row2 <= (col_cnt < PADDING || col_cnt >= IMG_W + PADDING) ? 0 : in_data;
            out_row1 <= (col_cnt < PADDING || col_cnt >= IMG_W + PADDING) ? 0 : buf1[col_cnt - PADDING];
            out_row0 <= (col_cnt < PADDING || col_cnt >= IMG_W + PADDING) ? 0 : buf2[col_cnt - PADDING];
            
            if (col_cnt >= PADDING && col_cnt < IMG_W + PADDING) begin
                buf1[col_cnt - PADDING] <= in_data;                  // load current data to buf1
                buf2[col_cnt - PADDING] <= buf1[col_cnt - PADDING];  // move buf1 to buf2 (previous row)
            end
            
            col_cnt <= (col_cnt == TOTAL_W - 1) ? 0 : col_cnt + 1;
        end
    end

endmodule
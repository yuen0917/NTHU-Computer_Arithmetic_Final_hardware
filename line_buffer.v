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

    // 為了修正延遲，我們計算一個 "Next Column Count" 給 Mask 邏輯使用
    wire [CNT_WIDTH-1:0] next_col_cnt;
    assign next_col_cnt = (col_cnt == TOTAL_W - 1) ? 0 : col_cnt + 1;


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
            // --------------------------------------------------------
            // 修正重點：使用 next_col_cnt 進行判斷
            // 當 col_cnt 為 0 (Padding) 時，next 為 1 (Data Start)。
            // 此時我們就應該允許寫入與輸出，因為當下的 in_data 就是 Data。
            // --------------------------------------------------------

            // 寫入 Buffer
            if (next_col_cnt >= PADDING && next_col_cnt < IMG_W + PADDING) begin
                buf1[next_col_cnt - PADDING] <= in_data;
                buf2[next_col_cnt - PADDING] <= buf1[next_col_cnt - PADDING];
            end

            // 輸出邏輯 (Masking)
            if (next_col_cnt >= PADDING && next_col_cnt < IMG_W + PADDING) begin
                out_row2 <= in_data;
                // 注意：讀取 buffer 仍用 next index，因為我們希望讀取到
                // 在 "上一個 Row" 同樣位置寫入的資料
                out_row1 <= buf1[next_col_cnt - PADDING];
                out_row0 <= buf2[next_col_cnt - PADDING];
            end else begin
                out_row2 <= 0;
                out_row1 <= 0;
                out_row0 <= 0;
            end

            col_cnt <= next_col_cnt;
        end
    end

endmodule
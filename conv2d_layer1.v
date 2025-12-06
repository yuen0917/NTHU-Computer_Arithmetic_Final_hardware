// ------------------------------------------------------------
// 2D Convolution Module with 8 channels with relu function
// ------------------------------------------------------------
module conv2d_layer1 #(
    parameter PADDING     = 1,
    parameter IMG_W       = 28,
    parameter IMG_H       = 28,
    parameter CH_IN       = 1,
    parameter CH_OUT      = 8,
    parameter QUANT_SHIFT = 10 // can be 8 ~ 12
)(
    input            clk,
    input            rst_n,
    input            in_valid,
    input      [7:0] in_data,
    output reg       out_valid,
    output reg [7:0] out_conv0,
    output reg [7:0] out_conv1,
    output reg [7:0] out_conv2,
    output reg [7:0] out_conv3,
    output reg [7:0] out_conv4,
    output reg [7:0] out_conv5,
    output reg [7:0] out_conv6,
    output reg [7:0] out_conv7
);
    localparam KERNEL_SIZE = 3 * 3;
    localparam WEIGHT_SIZE = CH_IN * CH_OUT * KERNEL_SIZE;
    localparam TOTAL_W     = IMG_W + 2 * PADDING;
    localparam TOTAL_H     = IMG_H + 2 * PADDING;
    localparam COL_CNT_W   = (TOTAL_W <= 1) ? 1 : $clog2(TOTAL_W);
    localparam ROW_CNT_W   = (TOTAL_H <= 1) ? 1 : $clog2(TOTAL_H);

    reg [COL_CNT_W:0] col_cnt;
    reg [ROW_CNT_W:0] row_cnt;

    reg signed [7:0] weight_data [0:WEIGHT_SIZE-1];

    wire [7:0] r0, r1, r2;

    initial begin
        $readmemh("conv1_relu.txt", weight_data);
    end

    // ------------------------------------------------------------
    // for modules
    // ------------------------------------------------------------
    line_buffer #(
        .IMG_W(IMG_W),
        .PADDING(PADDING)
    ) u_lb (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(in_data),
        .in_valid(in_valid),
        .out_row0(r0),
        .out_row1(r1),
        .out_row2(r2)
    );

    wire        [ 7:0] win00, win01, win02;
    wire        [ 7:0] win10, win11, win12;
    wire        [ 7:0] win20, win21, win22;
    wire signed [31:0] out_mac [0:CH_OUT - 1];

    window_generator u_wg (
        .clk(clk),
        .rst_n(rst_n),
        .r0(r0),
        .r1(r1),
        .r2(r2),
        .in_valid(in_valid),
        .win00(win00), .win01(win01), .win02(win02),
        .win10(win10), .win11(win11), .win12(win12),
        .win20(win20), .win21(win21), .win22(win22)
    );

    genvar i;
    generate
        for(i = 0; i < CH_OUT; i = i + 1) begin
            mac_3x3 u_mac_3x3 (
                .clk(clk),
                .rst_n(rst_n),
                .in_valid(in_valid),
                .win00(win00), .win01(win01), .win02(win02),
                .win10(win10), .win11(win11), .win12(win12),
                .win20(win20), .win21(win21), .win22(win22),
                .weight00(weight_data[i*KERNEL_SIZE + 0]),
                .weight01(weight_data[i*KERNEL_SIZE + 1]),
                .weight02(weight_data[i*KERNEL_SIZE + 2]),
                .weight10(weight_data[i*KERNEL_SIZE + 3]),
                .weight11(weight_data[i*KERNEL_SIZE + 4]),
                .weight12(weight_data[i*KERNEL_SIZE + 5]),
                .weight20(weight_data[i*KERNEL_SIZE + 6]),
                .weight21(weight_data[i*KERNEL_SIZE + 7]),
                .weight22(weight_data[i*KERNEL_SIZE + 8]),
                .out_mac(out_mac[i])
            );
        end
    endgenerate

    // ------------------------------------------------------------
    // for window valid signal
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 0;
            row_cnt <= 0;
        end else if (in_valid) begin
            if (col_cnt == IMG_W - 1) begin
                col_cnt <= 0;
                row_cnt <= (row_cnt == IMG_H - 1) ? 0 : row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end
        end
    end

    // 2. Check whether the input is valid (Raw Valid)
    // We need to determine whether the current (row, col) input makes the 3x3 window a valid position.
    //
    // The current input position corresponds to the bottom-right of the window (Win22).
    // The valid window center (Win11) must lie inside the image area (0~27).
    // Since Win22 is at (col, row), Win11 is at (col-1, row-1).
    // Considering pipeline latency, line buffer output is only valid when row >= 1 (two previous rows available).
    // Also, col must be >= 2 (window generator needs 2 extra cycles to fill Win00~Win02).
    wire input_region_valid;
    assign input_region_valid = (row_cnt >= 1) && (col_cnt >= 1);

    // 3. Shift register latency compensation
    // There are 4 pipeline stages: LineBuffer(1) + Window(1) + MAC(1) + Output(1) = 4 cycles.
    // However, input_region_valid is generated based on the current input timing.
    // The window generator has 1 cycle shift latency, and the line buffer output has 1 cycle latency.
    // Detailed timing:
    // T=0: Input (1,2) -> meets valid condition
    // T+1: Line buffer outputs r0, r1, r2
    // T+2: Window generator outputs winXX (Win11 corresponds to center)
    // T+3: MAC outputs the accumulated sum
    // T+4: Convolution module outputs the final result
    // Therefore, input_region_valid must be delayed by 4 cycles.

    reg [3:0] valid_pipe;      
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= 0;
        end else if (in_valid) begin
            // Shift only when in_valid is high, because the entire pipeline is driven by in_valid
            // Push input_region_valid into the shift register
            valid_pipe <= {valid_pipe[2:0], input_region_valid};
        end else begin
            // If in_valid is deasserted (e.g., waiting), the pipeline should also stop updating the valid status.
            // Depending on your design, you may want to insert 0 here (if the pipeline is flushed).
            // Here we assume a stall mechanism:
            valid_pipe <= {valid_pipe[2:0], 1'b0}; 
        end
    end                

    // ------------------------------------------------------------
    // for mac
    // ------------------------------------------------------------
    wire signed [31:0] tmp_mac [0:CH_OUT - 1];
    reg         [ 7:0] sat_val [0:CH_OUT - 1];

    generate
        for (i = 0; i < CH_OUT; i = i + 1) begin
            assign tmp_mac[i] = (out_mac[i] > 0) ? out_mac[i] >>> QUANT_SHIFT: 0;
        end
    endgenerate

    // ------------------------------------------------------------
    // for output
    // ------------------------------------------------------------
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid     <= 1'b0;
            out_conv0     <= 0;
            out_conv1     <= 0;
            out_conv2     <= 0;
            out_conv3     <= 0;
            out_conv4     <= 0;
            out_conv5     <= 0;
            out_conv6     <= 0;
            out_conv7     <= 0;
        end else if (in_valid) begin // include relu function
            for (k = 0; k < CH_OUT; k = k + 1) begin // relu
                sat_val[k] = (tmp_mac[k] > 255) ? 255 : tmp_mac[k][7:0];
            end

            out_valid <= valid_pipe[3];

            if (valid_pipe[3]) begin
                out_conv0 <= sat_val[0];
                out_conv1 <= sat_val[1];
                out_conv2 <= sat_val[2];
                out_conv3 <= sat_val[3];
                out_conv4 <= sat_val[4];
                out_conv5 <= sat_val[5];
                out_conv6 <= sat_val[6];
                out_conv7 <= sat_val[7];
            end
        end else begin
            out_valid <= 1'b0;
        end
    end
endmodule
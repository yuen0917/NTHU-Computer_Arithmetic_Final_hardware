`timescale 1ns/1ps
// ============================================================
// 2D Convolution Module with 8 channels with ReLU function
// ============================================================
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
    // if you want to use the clog2 function for verilog2001, you can use the following code
    // function integer clog2_func;
    // input integer value;
    // begin
    //     value = value - 1;
    //     for (clog2_func = 0; value > 0; clog2_func = clog2_func + 1) begin
    //         value = value >> 1;
    //     end
    // end
    // endfunction

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
        // $readmemh("import_file/conv1_relu.txt", weight_data);
        $readmemh("conv1_relu.txt", weight_data);
    end

    // ============================================================
    // for modules
    // ============================================================
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

    // ============================================================
    // for window valid signal (correction counter logic)
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 0;
            row_cnt <= 0;
        end else if (in_valid) begin
            if (col_cnt == IMG_W - 1) begin
                col_cnt <= 0;
                if (row_cnt == IMG_H - 1)
                    row_cnt <= 0;
                else
                    row_cnt <= row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end
        end
    end

    // ============================================================
    // correction: Valid determination logic
    // ============================================================
    reg input_region_valid;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) input_region_valid <= 0;
        else if (in_valid) begin
            if (row_cnt >= 1 || (row_cnt == 0 && col_cnt > 0))
               input_region_valid <= 1;
        end

    end

    wire start_output;
    wire active_row = (row_cnt >= 1);
    assign start_output = active_row;

    reg [3:0] conv_valid_pipe;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) conv_valid_pipe <= 0;
        else if (in_valid) conv_valid_pipe <= {conv_valid_pipe[2:0], start_output};
        else conv_valid_pipe <= {conv_valid_pipe[2:0], 1'b0};
    end


    // ============================================================
    // for mac output quantization and saturation
    // ============================================================
    wire signed [31:0] tmp_mac [0:CH_OUT - 1];
    reg         [ 7:0] sat_val [0:CH_OUT - 1];

    generate
        for (i = 0; i < CH_OUT; i = i + 1) begin
            assign tmp_mac[i] = (out_mac[i] > 0) ? out_mac[i] >>> QUANT_SHIFT: 0;
        end
    endgenerate

    // ============================================================
    // Output Assignment
    // ============================================================
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

            out_valid <= conv_valid_pipe[3];

            if (conv_valid_pipe[3]) begin
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

    // ============================================================
    // DEBUG BLOCK: Print Window Content
    // ============================================================
    always @(posedge clk) begin
        // when the control signal thinks that the current window is valid, print the content
        if (input_region_valid) begin
            $display("[RTL DEBUG] Time=%0t | Cnt=(c:%0d, r:%0d)", $time, col_cnt, row_cnt);
            $display("    Window Row 0: %d %d %d", win00, win01, win02);
            $display("    Window Row 1: %d %d %d", win10, win11, win12);
            $display("    Window Row 2: %d %d %d", win20, win21, win22);
            $display("    -------------------------");
        end
    end
endmodule
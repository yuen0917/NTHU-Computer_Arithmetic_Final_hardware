`timescale 1ns/1ps

module conv2d_layer1 #(
    // =========================================================================
    // 1. Parameter Definitions
    // =========================================================================
    parameter PADDING     = 1,
    parameter IMG_W       = 28,
    parameter IMG_H       = 28,
    parameter CH_IN       = 1,
    parameter CH_OUT      = 8,
    parameter QUANT_SHIFT = 7   // Quantization shift amount
)(
    // =========================================================================
    // 2. Input/Output Interface
    // =========================================================================
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

    // =========================================================================
    // 3. Internal Constants & Signal Declarations
    // =========================================================================
    localparam KERNEL_SIZE = 3 * 3;
    localparam WEIGHT_SIZE = CH_IN * CH_OUT * KERNEL_SIZE;
    localparam TOTAL_W     = IMG_W + 2 * PADDING;
    localparam TOTAL_H     = IMG_H + 2 * PADDING;
    // Calculate required bits for column counter
    localparam COL_CNT_W   = (TOTAL_W <= 1) ? 1 : $clog2(TOTAL_W);
    localparam ROW_CNT_W   = 6; // Assumes 6 bits is enough for IMG_H

    reg [COL_CNT_W:0] col_cnt;
    reg [ROW_CNT_W:0] row_cnt;

    // Weight storage array
    reg signed [7:0] weight_data [0:WEIGHT_SIZE-1];

    // Line Buffer output wires
    wire [7:0] r0, r1, r2;

    // =========================================================================
    // 4. Weight Initialization
    // =========================================================================
    initial begin
        $readmemh("conv1_relu.txt", weight_data);
    end

    // =========================================================================
    // 5. Line Buffer
    // Purpose: Buffers input rows to allow simultaneous access to 3 rows of data.
    // =========================================================================
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

    // Register Line Buffer outputs for timing alignment (1 cycle delay)
    reg [7:0] r0_d1;
    reg [7:0] r1_d1;
    reg [7:0] r2_d1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            r0_d1 <= 0;
            r1_d1 <= 0;
            r2_d1 <= 0;
        end else if(in_valid) begin
            r0_d1 <= r0;
            r1_d1 <= r1;
            r2_d1 <= r2;
        end
    end

    // =========================================================================
    // 6. Window Generator
    // Purpose: Converts 3 rows of streaming data into a 3x3 sliding window.
    // =========================================================================
    wire [7:0] win00, win01, win02;
    wire [7:0] win10, win11, win12;
    wire [7:0] win20, win21, win22;
    wire signed [31:0] out_mac [0:CH_OUT - 1]; // Results of MAC operations

    window_generator u_wg (
        .clk(clk),
        .rst_n(rst_n),
        .r0(r0_d1),
        .r1(r1_d1),
        .r2(r2_d1),
        .in_valid(in_valid),
        .win00(win00), .win01(win01), .win02(win02),
        .win10(win10), .win11(win11), .win12(win12),
        .win20(win20), .win21(win21), .win22(win22)
    );

    // =========================================================================
    // 7. Control Counters & Flush Logic
    // Purpose: Tracks current pixel (x, y) and handles pipeline flushing after input ends.
    // =========================================================================
    // Flush condition: Input ended but edge padding or remaining pixels still need processing
    wire need_flush = !in_valid && (row_cnt >= IMG_H && row_cnt <= IMG_H + 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 0;
            row_cnt <= 0;
        end else if (in_valid || need_flush) begin
            if (col_cnt >= IMG_W - 1) begin
                col_cnt <= 0;
                // Handle row_cnt wrapping or incrementing
                if (row_cnt == 60) // Note: 60 might be a specific magic number for the testbench
                    row_cnt <= 0;
                else
                    row_cnt <= row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end
        end
    end

    // =========================================================================
    // 8. Padding Mask Logic
    // Purpose: Applies zero-padding when the window is at the image boundary.
    // =========================================================================
    wire mask_left   = (col_cnt == 1);
    wire mask_right  = (col_cnt == 0);
    wire mask_top    = (row_cnt == 1);
    wire mask_bottom = (row_cnt == IMG_H);

    wire [7:0] m_win00, m_win01, m_win02;
    wire [7:0] m_win10, m_win11, m_win12;
    wire [7:0] m_win20, m_win21, m_win22;

    // Select original pixel or 0 based on boundary conditions
    assign m_win00 = (mask_top || mask_left)    ? 8'd0 : win00;
    assign m_win01 = (mask_top)                 ? 8'd0 : win01;
    assign m_win02 = (mask_top || mask_right)   ? 8'd0 : win02;

    assign m_win10 = (mask_left)                ? 8'd0 : win10;
    assign m_win11 = win11; // Center pixel usually doesn't need masking
    assign m_win12 = (mask_right)               ? 8'd0 : win12;

    assign m_win20 = (mask_bottom || mask_left)   ? 8'd0 : win20;
    assign m_win21 = (mask_bottom)                ? 8'd0 : win21;
    assign m_win22 = (mask_bottom || mask_right)  ? 8'd0 : win22;

    // =========================================================================
    // 9. Convolution MAC Array
    // Purpose: Parallel processing of 8 output channels (CH_OUT).
    // =========================================================================
    genvar i;
    generate
        for(i = 0; i < CH_OUT; i = i + 1) begin : GEN_MAC
            mac_3x3 #(.INPUT_IS_SIGNED(0)) u_mac_3x3 (
                .clk(clk),
                .rst_n(rst_n),
                .in_valid(in_valid),
                // Use masked window data
                .win00(m_win00), .win01(m_win01), .win02(m_win02),
                .win10(m_win10), .win11(m_win11), .win12(m_win12),
                .win20(m_win20), .win21(m_win21), .win22(m_win22),
                // Weights for the corresponding channel
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

    // =========================================================================
    // 10. Output Control & Pipeline
    // Purpose: Identifies valid output range and pipelines the valid signal.
    // =========================================================================
    wire valid_range_row = (row_cnt >= 2 && row_cnt <= IMG_H + 1);
    assign start_output = valid_range_row && (col_cnt < IMG_W);

    reg [2:0] conv_valid_pipe;
    wire flush_range = (row_cnt >= IMG_H && row_cnt <= IMG_H + 1);
    wire flush_valid = flush_range && (col_cnt < IMG_W);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) conv_valid_pipe <= 0;
        else begin
            if (in_valid) begin
                // Valid pipeline for normal input
                conv_valid_pipe <= {conv_valid_pipe[1:0], start_output};
            end else begin
                // Valid pipeline for flush stage
                conv_valid_pipe <= {conv_valid_pipe[1:0], flush_valid};
            end
        end
    end

    // =========================================================================
    // 11. Post-processing: Quantization & Activation (ReLU)
    // Purpose: Right-shift 32-bit results to 8-bit and apply ReLU/Saturation.
    // =========================================================================
    wire signed [31:0] tmp_mac [0:CH_OUT - 1];
    wire        [ 7:0] sat_val [0:CH_OUT - 1];

    generate
        for (i = 0; i < CH_OUT; i = i + 1) begin : GEN_SAT
            // Quantization: Arithmetic right shift
            // ReLU: If > 0 keep value, else 0
            assign tmp_mac[i] = (out_mac[i] > 0) ? (out_mac[i] >>> QUANT_SHIFT) : 32'd0;

            // Saturation: Clamp maximum value to 127
            assign sat_val[i] = (tmp_mac[i] > 127) ? 8'd127 : tmp_mac[i][7:0];
        end
    endgenerate

    // =========================================================================
    // 12. Output Registers
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_conv0 <= 0;
            out_conv1 <= 0;
            out_conv2 <= 0;
            out_conv3 <= 0;
            out_conv4 <= 0;
            out_conv5 <= 0;
            out_conv6 <= 0;
            out_conv7 <= 0;
        end else begin
            // Retrieve valid signal from pipeline
            out_valid <= conv_valid_pipe[2];

            if (conv_valid_pipe[1]) begin
                out_conv0 <= sat_val[0];
                out_conv1 <= sat_val[1];
                out_conv2 <= sat_val[2];
                out_conv3 <= sat_val[3];
                out_conv4 <= sat_val[4];
                out_conv5 <= sat_val[5];
                out_conv6 <= sat_val[6];
                out_conv7 <= sat_val[7];
            end
        end
    end

endmodule
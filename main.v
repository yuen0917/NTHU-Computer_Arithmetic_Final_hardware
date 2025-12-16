`timescale 1ns/1ps
// ============================================================
// Main Module
// ============================================================
module main (
    input                clk,
    input                rst_n,
    input                in_valid,
    input         [ 7:0] in_data,      // Input image (28x28)

    // Final output
    output        [ 3:0] class_out,   // Classification result (0~9)
    output               class_valid, // Classification result valid
    output signed [31:0] class_value, // Value of the classified class (optional)
    output signed [31:0] final_score, // Score of the classified class (optional)
    output               fc_out_valid // Score output valid (optional)
);
    localparam PADDING        = 1;
    localparam QUANT_SHIFT_L1 = 7;
    localparam QUANT_SHIFT_L2 = 7;
    localparam QUANT_SHIFT_L3 = 7;
    // =========================================================================
    // Layer 1: Conv2d (1 -> 8), 28x28, ReLU
    // =========================================================================
    wire       l1_valid;
    wire [7:0] l1_out0, l1_out1, l1_out2, l1_out3;
    wire [7:0] l1_out4, l1_out5, l1_out6, l1_out7;

    conv2d_layer1 #(
        .PADDING(PADDING), .IMG_W(28), .IMG_H(28), .CH_IN(1), .CH_OUT(8), .QUANT_SHIFT(QUANT_SHIFT_L1)
    ) u_layer1 (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data),
        .out_valid(l1_valid),
        .out_conv0(l1_out0), .out_conv1(l1_out1), .out_conv2(l1_out2), .out_conv3(l1_out3),
        .out_conv4(l1_out4), .out_conv5(l1_out5), .out_conv6(l1_out6), .out_conv7(l1_out7)
    );

    // =========================================================================
    // Layer 2: Conv2d (8 -> 16), 28x28, SELU
    // =========================================================================
    wire       l2_valid;
    wire [7:0] l2_out0,  l2_out1,  l2_out2,  l2_out3;
    wire [7:0] l2_out4,  l2_out5,  l2_out6,  l2_out7;
    wire [7:0] l2_out8,  l2_out9,  l2_out10, l2_out11;
    wire [7:0] l2_out12, l2_out13, l2_out14, l2_out15;

    conv2d_layer2 #(
        .PADDING(PADDING), .IMG_W(28), .IMG_H(28), .CH_IN(8), .CH_OUT(16), .QUANT_SHIFT(QUANT_SHIFT_L2)
    ) u_layer2 (
        .clk(clk), .rst_n(rst_n), .in_valid(l1_valid),
        .in_data0(l1_out0), .in_data1(l1_out1), .in_data2(l1_out2), .in_data3(l1_out3),
        .in_data4(l1_out4), .in_data5(l1_out5), .in_data6(l1_out6), .in_data7(l1_out7),
        .out_valid(l2_valid),
        .out_conv0 (l2_out0),  .out_conv1 (l2_out1),  .out_conv2 (l2_out2),  .out_conv3 (l2_out3),
        .out_conv4 (l2_out4),  .out_conv5 (l2_out5),  .out_conv6 (l2_out6),  .out_conv7 (l2_out7),
        .out_conv8 (l2_out8),  .out_conv9 (l2_out9),  .out_conv10(l2_out10), .out_conv11(l2_out11),
        .out_conv12(l2_out12), .out_conv13(l2_out13), .out_conv14(l2_out14), .out_conv15(l2_out15)
    );

    // =========================================================================
    // Layer 3: Max Pooling (2x2), Output becomes 14x14
    // Need 16 instances for 16 channels
    // =========================================================================
    // Packing wires for Generate Loop
    wire [7:0] l2_pack [0:15];
    assign l2_pack[0]  = l2_out0;   assign l2_pack[1]  = l2_out1;   assign l2_pack[2]  = l2_out2;   assign l2_pack[3]  = l2_out3;
    assign l2_pack[4]  = l2_out4;   assign l2_pack[5]  = l2_out5;   assign l2_pack[6]  = l2_out6;   assign l2_pack[7]  = l2_out7;
    assign l2_pack[8]  = l2_out8;   assign l2_pack[9]  = l2_out9;   assign l2_pack[10] = l2_out10;  assign l2_pack[11] = l2_out11;
    assign l2_pack[12] = l2_out12;  assign l2_pack[13] = l2_out13;  assign l2_pack[14] = l2_out14;  assign l2_pack[15] = l2_out15;

    wire [7:0] mp_out_pack   [0:15];
    wire       mp_valid_pack [0:15]; // Theoretical identical valid signals

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : MP_INST
            max_pool_unit #(
                .IMG_W(28), .IMG_H(28) // Input size is 28x28
            ) u_mp (
                .clk(clk), .rst_n(rst_n),
                .in_valid(l2_valid),
                .in_data(l2_pack[i]),
                .out_valid(mp_valid_pack[i]),
                .out_data(mp_out_pack[i])
            );
        end
    endgenerate

    // DEBUG: Track MP output
    always @(posedge clk) begin
        if (mp_valid_pack[0] && $time < 10000) begin  // Only show first few
            $display("[MP] OUTPUT: out_valid=1, out_data[0]=%d, out_data[15]=%d",
                     mp_out_pack[0], mp_out_pack[15]);
        end
    end

    // =========================================================================
    // FIFO Buffer between MP and L3
    // =========================================================================
    wire [7:0] fifo_rd_data0, fifo_rd_data1, fifo_rd_data2, fifo_rd_data3;
    wire [7:0] fifo_rd_data4, fifo_rd_data5, fifo_rd_data6, fifo_rd_data7;
    wire [7:0] fifo_rd_data8, fifo_rd_data9, fifo_rd_data10, fifo_rd_data11;
    wire [7:0] fifo_rd_data12, fifo_rd_data13, fifo_rd_data14, fifo_rd_data15;
    wire fifo_rd_valid;
    wire fifo_empty;
    wire fifo_full;

    wire l3_rd_en;

    fifo_mp_l3 #(
        .DATA_WIDTH(8),
        .CHANNELS(16),
        .DEPTH(256),
        .IMAGE_SIZE(3136)  // 14x14x16 = 3136 pixels
    ) u_fifo_mp_l3 (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(mp_valid_pack[0]),
        .wr_data0(mp_out_pack[0]), .wr_data1(mp_out_pack[1]), .wr_data2(mp_out_pack[2]), .wr_data3(mp_out_pack[3]),
        .wr_data4(mp_out_pack[4]), .wr_data5(mp_out_pack[5]), .wr_data6(mp_out_pack[6]), .wr_data7(mp_out_pack[7]),
        .wr_data8(mp_out_pack[8]), .wr_data9(mp_out_pack[9]), .wr_data10(mp_out_pack[10]), .wr_data11(mp_out_pack[11]),
        .wr_data12(mp_out_pack[12]), .wr_data13(mp_out_pack[13]), .wr_data14(mp_out_pack[14]), .wr_data15(mp_out_pack[15]),
        .rd_en(l3_rd_en),
        .rd_data0(fifo_rd_data0), .rd_data1(fifo_rd_data1), .rd_data2(fifo_rd_data2), .rd_data3(fifo_rd_data3),
        .rd_data4(fifo_rd_data4), .rd_data5(fifo_rd_data5), .rd_data6(fifo_rd_data6), .rd_data7(fifo_rd_data7),
        .rd_data8(fifo_rd_data8), .rd_data9(fifo_rd_data9), .rd_data10(fifo_rd_data10), .rd_data11(fifo_rd_data11),
        .rd_data12(fifo_rd_data12), .rd_data13(fifo_rd_data13), .rd_data14(fifo_rd_data14), .rd_data15(fifo_rd_data15),
        .rd_valid(fifo_rd_valid),
        .empty(fifo_empty),
        .full(fifo_full),
        .count(),
        .batch_ready(fifo_batch_ready),
        .last_batch(fifo_last_batch)
    );

    // =========================================================================
    // Layer 4: Conv2d (16 -> 32), 14x14, GELU
    // =========================================================================
    wire       l4_valid;
    wire [7:0] l4_out_w [0:31];

    conv2d_layer3 #(
        .PADDING(PADDING), .IMG_W(14), .IMG_H(14), .CH_IN(16), .CH_OUT(32), .QUANT_SHIFT(QUANT_SHIFT_L3)
    ) u_layer4 (
        .clk(clk), .rst_n(rst_n), .in_valid(fifo_rd_valid),
        // Connect inputs from FIFO
        .in_data0 (fifo_rd_data0),  .in_data1 (fifo_rd_data1),  .in_data2 (fifo_rd_data2),  .in_data3 (fifo_rd_data3),
        .in_data4 (fifo_rd_data4),  .in_data5 (fifo_rd_data5),  .in_data6 (fifo_rd_data6),  .in_data7 (fifo_rd_data7),
        .in_data8 (fifo_rd_data8),  .in_data9 (fifo_rd_data9),  .in_data10(fifo_rd_data10), .in_data11(fifo_rd_data11),
        .in_data12(fifo_rd_data12), .in_data13(fifo_rd_data13), .in_data14(fifo_rd_data14), .in_data15(fifo_rd_data15),
        // FIFO status signal
        .fifo_empty(fifo_empty),
        .fifo_batch_ready(fifo_batch_ready),
        .fifo_last_batch(fifo_last_batch),
        .calc_busy_out(),
        .rd_en_out(l3_rd_en),
        .out_valid(l4_valid),
        // Connect outputs to wire array
        .out_conv0 (l4_out_w[0]),  .out_conv1 (l4_out_w[1]),  .out_conv2 (l4_out_w[2]),  .out_conv3 (l4_out_w[3]),
        .out_conv4 (l4_out_w[4]),  .out_conv5 (l4_out_w[5]),  .out_conv6 (l4_out_w[6]),  .out_conv7 (l4_out_w[7]),
        .out_conv8 (l4_out_w[8]),  .out_conv9 (l4_out_w[9]),  .out_conv10(l4_out_w[10]), .out_conv11(l4_out_w[11]),
        .out_conv12(l4_out_w[12]), .out_conv13(l4_out_w[13]), .out_conv14(l4_out_w[14]), .out_conv15(l4_out_w[15]),
        .out_conv16(l4_out_w[16]), .out_conv17(l4_out_w[17]), .out_conv18(l4_out_w[18]), .out_conv19(l4_out_w[19]),
        .out_conv20(l4_out_w[20]), .out_conv21(l4_out_w[21]), .out_conv22(l4_out_w[22]), .out_conv23(l4_out_w[23]),
        .out_conv24(l4_out_w[24]), .out_conv25(l4_out_w[25]), .out_conv26(l4_out_w[26]), .out_conv27(l4_out_w[27]),
        .out_conv28(l4_out_w[28]), .out_conv29(l4_out_w[29]), .out_conv30(l4_out_w[30]), .out_conv31(l4_out_w[31])
    );

    // =========================================================================
    // Layer 5: Global Average Pooling (32 channels), 14x14 -> 1x1
    // =========================================================================
    wire [7:0] gap_out_pack   [0:31];
    wire       gap_valid_pack [0:31];

    generate
        for (i = 0; i < 32; i = i + 1) begin : GAP_INST
            global_avg_pool_unit #(
                .IMG_W(14), .IMG_H(14)
            ) u_gap (
                .clk(clk), .rst_n(rst_n),
                .in_valid(l4_valid),
                .in_data(l4_out_w[i]),
                .out_valid(gap_valid_pack[i]),
                .out_data(gap_out_pack[i])
            );
        end
    endgenerate

    wire gap_valid_global = gap_valid_pack[0];

    // =========================================================================
    // Layer 6: Flatten (Parallel to Serial Converter)
    // =========================================================================
    reg [7:0] flatten_buf [0:31];
    reg [5:0] flat_cnt;
    reg       sending_to_fc;

    reg [7:0] fc_in_data;
    reg       fc_in_valid;
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flat_cnt      <= 0;
            sending_to_fc <= 0;
            fc_in_valid   <= 0;
            fc_in_data    <= 0;
            for(k = 0; k < 32; k = k + 1) flatten_buf[k] <= 0;
        end else begin
            if (gap_valid_global) begin
                for(k = 0; k < 32; k = k + 1) begin
                    flatten_buf[k] <= gap_out_pack[k];
                end
                sending_to_fc <= 1;
                flat_cnt      <= 0;
                fc_in_valid   <= 0;
            end
            else if (sending_to_fc) begin
                if (flat_cnt < 32) begin
                    fc_in_data  <= flatten_buf[flat_cnt];
                    fc_in_valid <= 1;
                    flat_cnt    <= flat_cnt + 1;
                end else begin
                    sending_to_fc <= 0;
                    fc_in_valid   <= 0;
                    flat_cnt      <= 0;
                end
            end else begin
                fc_in_valid <= 0;
            end
        end
    end

    // =========================================================================
    // Layer 7: Fully Connected + Softmax
    // =========================================================================
    fc_softmax_unit #(
        .IN_DIM(32),
        .OUT_DIM(10)
    ) u_fc (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(fc_in_data),
        .in_valid(fc_in_valid),
        .out_data(final_score),
        .out_valid(fc_out_valid),
        .class_out(class_out),
        .class_valid(class_valid),
        .class_value(class_value)
    );

endmodule

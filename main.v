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
    localparam PADDING = 1;
    localparam QUANT_SHIFT = 8;
    // =========================================================================
    // Layer 1: Conv2d (1 -> 8), 28x28, ReLU
    // =========================================================================
    wire       l1_valid;
    wire [7:0] l1_out0, l1_out1, l1_out2, l1_out3;
    wire [7:0] l1_out4, l1_out5, l1_out6, l1_out7;

    conv2d_layer1 #(
        .PADDING(PADDING), .IMG_W(28), .IMG_H(28), .CH_IN(1), .CH_OUT(8), .QUANT_SHIFT(QUANT_SHIFT)
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
        .PADDING(PADDING), .IMG_W(28), .IMG_H(28), .CH_IN(8), .CH_OUT(16), .QUANT_SHIFT(QUANT_SHIFT)
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

    wire l3_in_valid = mp_valid_pack[0]; // Use channel 0 valid as global valid for next layer

    // =========================================================================
    // Layer 4: Conv2d (16 -> 32), 14x14, GELU
    // =========================================================================
    wire       l4_valid;
    // Layer 4 outputs 32 channels. We can define wires or capture them directly into an array if DUT allows.
    // Since your module definition uses discrete ports, let's wire them out.
    // To save lines, I will capture them into an array immediately in the assignment below.
    // But first, we need wires to connect to the ports.
    wire [7:0] l4_out_w [0:31];

    conv2d_layer3 #(
        .PADDING(PADDING), .IMG_W(14), .IMG_H(14), .CH_IN(16), .CH_OUT(32), .QUANT_SHIFT(QUANT_SHIFT)
    ) u_layer4 (
        .clk(clk), .rst_n(rst_n), .in_valid(l3_in_valid),
        // Connect inputs from MaxPool array
        .in_data0 (mp_out_pack[0]),  .in_data1 (mp_out_pack[1]),  .in_data2 (mp_out_pack[2]),  .in_data3 (mp_out_pack[3]),
        .in_data4 (mp_out_pack[4]),  .in_data5 (mp_out_pack[5]),  .in_data6 (mp_out_pack[6]),  .in_data7 (mp_out_pack[7]),
        .in_data8 (mp_out_pack[8]),  .in_data9 (mp_out_pack[9]),  .in_data10(mp_out_pack[10]), .in_data11(mp_out_pack[11]),
        .in_data12(mp_out_pack[12]), .in_data13(mp_out_pack[13]), .in_data14(mp_out_pack[14]), .in_data15(mp_out_pack[15]),

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
    // Need 32 instances
    // =========================================================================
    wire [7:0] gap_out_pack   [0:31];
    wire       gap_valid_pack [0:31];

    generate
        for (i = 0; i < 32; i = i + 1) begin : GAP_INST
            global_avg_pool_unit #(
                .IMG_W(14), .IMG_H(14) // Input size is 14x14
            ) u_gap (
                .clk(clk), .rst_n(rst_n),
                .in_valid(l4_valid),
                .in_data(l4_out_w[i]),
                .out_valid(gap_valid_pack[i]),
                .out_data(gap_out_pack[i])
            );
        end
    endgenerate

    wire gap_valid_global = gap_valid_pack[0]; // All 32 GAPs finish at the same time

    // =========================================================================
    // Layer 6: Flatten (Parallel to Serial Converter)
    // The FC unit accepts serial input (one value per cycle), but GAP gives 32 values at once.
    // We need to capture the 32 GAP values and feed them to FC one by one.
    // =========================================================================
    reg [7:0] flatten_buf [0:31];
    reg [5:0] flat_cnt; // Counts 0 to 31
    reg       sending_to_fc;

    // Signals for FC
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
            // 1. Capture Data from GAP
            if (gap_valid_global) begin
                for(k = 0; k < 32; k = k + 1) begin
                    flatten_buf[k] <= gap_out_pack[k];
                end
                sending_to_fc <= 1;
                flat_cnt      <= 0;
                fc_in_valid   <= 0; // Will be valid next cycle
            end
            // 2. Send Data to FC Serial
            else if (sending_to_fc) begin
                if (flat_cnt < 32) begin
                    fc_in_data  <= flatten_buf[flat_cnt];
                    fc_in_valid <= 1;
                    flat_cnt    <= flat_cnt + 1;
                end else begin
                    // Done sending 32 values
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
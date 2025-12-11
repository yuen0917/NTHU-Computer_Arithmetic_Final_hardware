`timescale 1ns/1ps
// ============================================================
// 2D Convolution Module with 32 channels (16 input channels) with GELU function
// ============================================================
module conv2d_layer3 #(
    parameter PADDING     = 1,
    parameter IMG_W       = 28,
    parameter IMG_H       = 28,
    parameter CH_IN       = 16,
    parameter CH_OUT      = 32,
    parameter QUANT_SHIFT = 10 // can be 8 ~ 12
)(
    input            clk,
    input            rst_n,
    input            in_valid,
    input      [7:0] in_data0,
    input      [7:0] in_data1,
    input      [7:0] in_data2,
    input      [7:0] in_data3,
    input      [7:0] in_data4,
    input      [7:0] in_data5,
    input      [7:0] in_data6,
    input      [7:0] in_data7,
    input      [7:0] in_data8,
    input      [7:0] in_data9,
    input      [7:0] in_data10,
    input      [7:0] in_data11,
    input      [7:0] in_data12,
    input      [7:0] in_data13,
    input      [7:0] in_data14,
    input      [7:0] in_data15,
    output reg       out_valid,
    output reg [7:0] out_conv0,
    output reg [7:0] out_conv1,
    output reg [7:0] out_conv2,
    output reg [7:0] out_conv3,
    output reg [7:0] out_conv4,
    output reg [7:0] out_conv5,
    output reg [7:0] out_conv6,
    output reg [7:0] out_conv7,
    output reg [7:0] out_conv8,
    output reg [7:0] out_conv9,
    output reg [7:0] out_conv10,
    output reg [7:0] out_conv11,
    output reg [7:0] out_conv12,
    output reg [7:0] out_conv13,
    output reg [7:0] out_conv14,
    output reg [7:0] out_conv15,
    output reg [7:0] out_conv16,
    output reg [7:0] out_conv17,
    output reg [7:0] out_conv18,
    output reg [7:0] out_conv19,
    output reg [7:0] out_conv20,
    output reg [7:0] out_conv21,
    output reg [7:0] out_conv22,
    output reg [7:0] out_conv23,
    output reg [7:0] out_conv24,
    output reg [7:0] out_conv25,
    output reg [7:0] out_conv26,
    output reg [7:0] out_conv27,
    output reg [7:0] out_conv28,
    output reg [7:0] out_conv29,
    output reg [7:0] out_conv30,
    output reg [7:0] out_conv31
);

    localparam KERNEL_SIZE = 3 * 3;
    localparam WEIGHT_SIZE = CH_IN * CH_OUT * KERNEL_SIZE;
    localparam COL_CNT_W   = (IMG_W <= 1) ? 1 : $clog2(IMG_W);
    localparam ROW_CNT_W   = (IMG_H <= 1) ? 1 : $clog2(IMG_H);

    reg [COL_CNT_W:0] col_cnt;
    reg [ROW_CNT_W:0] row_cnt;

    reg signed [7:0] weight_data [0:WEIGHT_SIZE-1];

    // Map inputs to array
    wire [7:0] in_data_wire [0:CH_IN-1];
    assign in_data_wire[0]  = in_data0;  assign in_data_wire[1]  = in_data1;
    assign in_data_wire[2]  = in_data2;  assign in_data_wire[3]  = in_data3;
    assign in_data_wire[4]  = in_data4;  assign in_data_wire[5]  = in_data5;
    assign in_data_wire[6]  = in_data6;  assign in_data_wire[7]  = in_data7;
    assign in_data_wire[8]  = in_data8;  assign in_data_wire[9]  = in_data9;
    assign in_data_wire[10] = in_data10; assign in_data_wire[11] = in_data11;
    assign in_data_wire[12] = in_data12; assign in_data_wire[13] = in_data13;
    assign in_data_wire[14] = in_data14; assign in_data_wire[15] = in_data15;

    wire [7:0] r0 [0:CH_IN-1];
    wire [7:0] r1 [0:CH_IN-1];
    wire [7:0] r2 [0:CH_IN-1];

    initial begin
        // Change file name for Layer 3 weights
        // $readmemh("import_file/conv3_gelu.txt", weight_data);
        $readmemh("conv3_gelu.txt", weight_data);
    end

    // ============================================================
    // Line Buffers & Window Generators (16 instances)
    // ============================================================
    genvar i;
    wire [7:0] win00 [0:CH_IN-1], win01 [0:CH_IN-1], win02 [0:CH_IN-1];
    wire [7:0] win10 [0:CH_IN-1], win11 [0:CH_IN-1], win12 [0:CH_IN-1];
    wire [7:0] win20 [0:CH_IN-1], win21 [0:CH_IN-1], win22 [0:CH_IN-1];

    generate
        for(i = 0; i < CH_IN; i = i + 1) begin : LB_WIN_GEN
            line_buffer #(
                .IMG_W(IMG_W),
                .PADDING(PADDING)
            ) u_lb (
                .clk(clk),
                .rst_n(rst_n),
                .in_data(in_data_wire[i]),
                .in_valid(in_valid),
                .out_row0(r0[i]),
                .out_row1(r1[i]),
                .out_row2(r2[i])
            );
            window_generator u_wg (
                .clk(clk),
                .rst_n(rst_n),
                .r0(r0[i]), .r1(r1[i]), .r2(r2[i]),
                .in_valid(in_valid),
                .win00(win00[i]), .win01(win01[i]), .win02(win02[i]),
                .win10(win10[i]), .win11(win11[i]), .win12(win12[i]),
                .win20(win20[i]), .win21(win21[i]), .win22(win22[i])
            );
        end
    endgenerate

    // ============================================================
    // MAC Units (32 outputs * 16 inputs = 512 MACs)
    // ============================================================
    wire signed [31:0] out_mac_per_ch [0:CH_OUT-1][0:CH_IN-1];
    wire signed [31:0] out_mac [0:CH_OUT-1];

    genvar out_ch, in_ch;
    generate
        for(out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin : MAC_OUT_LOOP
            for(in_ch = 0; in_ch < CH_IN; in_ch = in_ch + 1) begin : MAC_IN_LOOP
                mac_3x3 #(.INPUT_IS_SIGNED(1)) u_mac_3x3 (
                    .clk(clk),
                    .rst_n(rst_n),
                    .in_valid(in_valid),
                    .win00(win00[in_ch]), .win01(win01[in_ch]), .win02(win02[in_ch]),
                    .win10(win10[in_ch]), .win11(win11[in_ch]), .win12(win12[in_ch]),
                    .win20(win20[in_ch]), .win21(win21[in_ch]), .win22(win22[in_ch]),
                    // Weight indexing: (out_ch * 16 + in_ch) * 9 + k_idx
                    .weight00(weight_data[(out_ch * CH_IN + in_ch) * KERNEL_SIZE + 0]),
                    .weight01(weight_data[(out_ch * CH_IN + in_ch) * KERNEL_SIZE + 1]),
                    .weight02(weight_data[(out_ch * CH_IN + in_ch) * KERNEL_SIZE + 2]),
                    .weight10(weight_data[(out_ch * CH_IN + in_ch) * KERNEL_SIZE + 3]),
                    .weight11(weight_data[(out_ch * CH_IN + in_ch) * KERNEL_SIZE + 4]),
                    .weight12(weight_data[(out_ch * CH_IN + in_ch) * KERNEL_SIZE + 5]),
                    .weight20(weight_data[(out_ch * CH_IN + in_ch) * KERNEL_SIZE + 6]),
                    .weight21(weight_data[(out_ch * CH_IN + in_ch) * KERNEL_SIZE + 7]),
                    .weight22(weight_data[(out_ch * CH_IN + in_ch) * KERNEL_SIZE + 8]),
                    .out_mac(out_mac_per_ch[out_ch][in_ch])
                );
            end
        end
    endgenerate

    // ============================================================
    // Adder Tree (Sum 16 inputs for each output channel)
    // Structure: 16 -> 8 -> 4 -> 2 -> 1
    // ============================================================
    generate
        for(out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin : ADDER_TREE_GEN
            wire signed [31:0] sum_stage1 [0:7]; // 16 -> 8
            wire signed [31:0] sum_stage2 [0:3]; // 8 -> 4
            wire signed [31:0] sum_stage3 [0:1]; // 4 -> 2

            // Stage 1 (16 -> 8)
            assign sum_stage1[0] = out_mac_per_ch[out_ch][0]  + out_mac_per_ch[out_ch][1];
            assign sum_stage1[1] = out_mac_per_ch[out_ch][2]  + out_mac_per_ch[out_ch][3];
            assign sum_stage1[2] = out_mac_per_ch[out_ch][4]  + out_mac_per_ch[out_ch][5];
            assign sum_stage1[3] = out_mac_per_ch[out_ch][6]  + out_mac_per_ch[out_ch][7];
            assign sum_stage1[4] = out_mac_per_ch[out_ch][8]  + out_mac_per_ch[out_ch][9];
            assign sum_stage1[5] = out_mac_per_ch[out_ch][10] + out_mac_per_ch[out_ch][11];
            assign sum_stage1[6] = out_mac_per_ch[out_ch][12] + out_mac_per_ch[out_ch][13];
            assign sum_stage1[7] = out_mac_per_ch[out_ch][14] + out_mac_per_ch[out_ch][15];

            // Stage 2 (8 -> 4)
            assign sum_stage2[0] = sum_stage1[0] + sum_stage1[1];
            assign sum_stage2[1] = sum_stage1[2] + sum_stage1[3];
            assign sum_stage2[2] = sum_stage1[4] + sum_stage1[5];
            assign sum_stage2[3] = sum_stage1[6] + sum_stage1[7];

            // Stage 3 (4 -> 2)
            assign sum_stage3[0] = sum_stage2[0] + sum_stage2[1];
            assign sum_stage3[1] = sum_stage2[2] + sum_stage2[3];

            // Final Sum (2 -> 1)
            assign out_mac[out_ch] = sum_stage3[0] + sum_stage3[1];
        end
    endgenerate

    // ============================================================
    // Counters & Control Logic
    // ============================================================
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

    reg input_region_valid;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) input_region_valid <= 0;
        else if (in_valid) begin
            if (row_cnt >= 1 || (row_cnt == 0 && col_cnt > 0))
               input_region_valid <= 1;
        end
    end

    wire start_output;
    assign start_output = (row_cnt >= 1);

    reg [2:0] conv_valid_pipe;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) conv_valid_pipe <= 0;
        else if (in_valid) conv_valid_pipe <= {conv_valid_pipe[1:0], start_output};
        else conv_valid_pipe <= {conv_valid_pipe[1:0], 1'b0};
    end

    // ============================================================
    // Quantization & GELU Integration
    // ============================================================
    wire signed [7:0] gelu_in [0:CH_OUT-1];
    wire signed [7:0] gelu_out [0:CH_OUT-1];
    wire              gelu_out_valid [0:CH_OUT-1];

    generate
        for (out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin : GELU_GEN
            // Quantization
            wire signed [31:0] scaled_mac = out_mac[out_ch] >>> QUANT_SHIFT;

            // Clipping
            assign gelu_in[out_ch] = (scaled_mac > 127)  ? 8'sd127 :
                                     (scaled_mac < -128) ? -8'sd128 :
                                     scaled_mac[7:0];

            // Instantiate GELU LUT (make sure gelu_lut_act module exists)
            gelu_lut_act u_gelu (
                .clk(clk),
                .rst_n(rst_n),
                .in_valid(conv_valid_pipe[2]),
                .in_data(gelu_in[out_ch]),
                .out_valid(gelu_out_valid[out_ch]),
                .out_data(gelu_out[out_ch])
            );
        end
    endgenerate

    // ============================================================
    // Output Assignment
    // ============================================================
    always @(*) begin
        out_valid   = gelu_out_valid[0];

        out_conv0   = gelu_out[0];   out_conv1   = gelu_out[1];   out_conv2   = gelu_out[2];   out_conv3   = gelu_out[3];
        out_conv4   = gelu_out[4];   out_conv5   = gelu_out[5];   out_conv6   = gelu_out[6];   out_conv7   = gelu_out[7];
        out_conv8   = gelu_out[8];   out_conv9   = gelu_out[9];   out_conv10  = gelu_out[10];  out_conv11  = gelu_out[11];
        out_conv12  = gelu_out[12];  out_conv13  = gelu_out[13];  out_conv14  = gelu_out[14];  out_conv15  = gelu_out[15];
        out_conv16  = gelu_out[16];  out_conv17  = gelu_out[17];  out_conv18  = gelu_out[18];  out_conv19  = gelu_out[19];
        out_conv20  = gelu_out[20];  out_conv21  = gelu_out[21];  out_conv22  = gelu_out[22];  out_conv23  = gelu_out[23];
        out_conv24  = gelu_out[24];  out_conv25  = gelu_out[25];  out_conv26  = gelu_out[26];  out_conv27  = gelu_out[27];
        out_conv28  = gelu_out[28];  out_conv29  = gelu_out[29];  out_conv30  = gelu_out[30];  out_conv31  = gelu_out[31];
    end
endmodule
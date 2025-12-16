`timescale 1ns/1ps
// ============================================================
// 2D Convolution Module with 16 channels (8 input channels) with SELU function
// ============================================================
module conv2d_layer2 #(
  parameter PADDING     = 1,
  parameter IMG_W       = 28,
  parameter IMG_H       = 28,
  parameter CH_IN       = 8,
  parameter CH_OUT      = 16,
  parameter QUANT_SHIFT = 7
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
  output reg [7:0] out_conv15
);

    localparam KERNEL_SIZE = 3 * 3;
    localparam WEIGHT_SIZE = CH_IN * CH_OUT * KERNEL_SIZE;
    localparam COL_CNT_W   = (IMG_W <= 1) ? 1 : $clog2(IMG_W);
    localparam ROW_CNT_W   = 6;

    reg [COL_CNT_W:0] col_cnt;
    reg [ROW_CNT_W:0] row_cnt;

    reg signed [7:0] weight_data [0:WEIGHT_SIZE-1];

    wire [7:0] in_data_wire [0:CH_IN-1];

    assign in_data_wire[0] = in_data0;
    assign in_data_wire[1] = in_data1;
    assign in_data_wire[2] = in_data2;
    assign in_data_wire[3] = in_data3;
    assign in_data_wire[4] = in_data4;
    assign in_data_wire[5] = in_data5;
    assign in_data_wire[6] = in_data6;
    assign in_data_wire[7] = in_data7;

    wire [7:0] r0 [0:CH_IN-1];
    wire [7:0] r1 [0:CH_IN-1];
    wire [7:0] r2 [0:CH_IN-1];

    initial begin
      $readmemh("conv2_selu.txt", weight_data);
    end

    // ============================================================
    // Line Buffers
    // ============================================================
    genvar i;
    generate
      for(i = 0; i < CH_IN; i = i + 1) begin : LINE_BUFFERS
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
      end
    endgenerate

    // ============================================================
    // Data Delay (Sync Strategy: Delay 1 Cycle)
    // ============================================================
    reg [7:0] r0_d1 [0:CH_IN-1];
    reg [7:0] r1_d1 [0:CH_IN-1];
    reg [7:0] r2_d1 [0:CH_IN-1];

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(k=0; k<CH_IN; k=k+1) begin
                r0_d1[k] <= 0;
                r1_d1[k] <= 0;
                r2_d1[k] <= 0;
            end
        end else if(in_valid) begin
            for(k=0; k<CH_IN; k=k+1) begin
                r0_d1[k] <= r0[k];
                r1_d1[k] <= r1[k];
                r2_d1[k] <= r2[k];
            end
        end
    end

    // ============================================================
    // Window Generators
    // ============================================================
    wire [7:0] win00 [0:CH_IN-1];
    wire [7:0] win01 [0:CH_IN-1];
    wire [7:0] win02 [0:CH_IN-1];
    wire [7:0] win10 [0:CH_IN-1];
    wire [7:0] win11 [0:CH_IN-1];
    wire [7:0] win12 [0:CH_IN-1];
    wire [7:0] win20 [0:CH_IN-1];
    wire [7:0] win21 [0:CH_IN-1];
    wire [7:0] win22 [0:CH_IN-1];

    generate
      for(i = 0; i < CH_IN; i = i + 1) begin : WINDOW_GENS
        window_generator u_wg (
          .clk(clk),
          .rst_n(rst_n),
          .r0(r0_d1[i]),
          .r1(r1_d1[i]),
          .r2(r2_d1[i]),
          .in_valid(in_valid),
          .win00(win00[i]), .win01(win01[i]), .win02(win02[i]),
          .win10(win10[i]), .win11(win11[i]), .win12(win12[i]),
          .win20(win20[i]), .win21(win21[i]), .win22(win22[i])
        );
      end
    endgenerate

    // ============================================================
    // Padding Masking Logic (Shared across all input channels)
    // ============================================================
    wire mask_left   = (col_cnt == 4);
    wire mask_right  = (col_cnt == 3);
    wire mask_top    = (row_cnt == 1);
    wire mask_bottom = (row_cnt == 0);

    wire [7:0] m_win00 [0:CH_IN-1];
    wire [7:0] m_win01 [0:CH_IN-1];
    wire [7:0] m_win02 [0:CH_IN-1];
    wire [7:0] m_win10 [0:CH_IN-1];
    wire [7:0] m_win11 [0:CH_IN-1];
    wire [7:0] m_win12 [0:CH_IN-1];
    wire [7:0] m_win20 [0:CH_IN-1];
    wire [7:0] m_win21 [0:CH_IN-1];
    wire [7:0] m_win22 [0:CH_IN-1];

    generate
      for(i = 0; i < CH_IN; i = i + 1) begin : MASK_GEN
        assign m_win00[i] = (mask_top || mask_left)   ? 8'd0 : win00[i];
        assign m_win01[i] = (mask_top)                ? 8'd0 : win01[i];
        assign m_win02[i] = (mask_top || mask_right)  ? 8'd0 : win02[i];

        assign m_win10[i] = (mask_left)               ? 8'd0 : win10[i];
        assign m_win11[i] = win11[i];
        assign m_win12[i] = (mask_right)              ? 8'd0 : win12[i];

        assign m_win20[i] = (mask_bottom || mask_left)  ? 8'd0 : win20[i];
        assign m_win21[i] = (mask_bottom)               ? 8'd0 : win21[i];
        assign m_win22[i] = (mask_bottom || mask_right) ? 8'd0 : win22[i];
      end
    endgenerate

    // ============================================================
    // MAC Units for each output channel
    // ============================================================
    wire signed [31:0] out_mac_per_ch [0:CH_OUT-1][0:CH_IN-1];
    wire signed [31:0] out_mac [0:CH_OUT-1];

    genvar out_ch, in_ch;
    generate
      for(out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin : MAC_OUT_LOOP
        for(in_ch = 0; in_ch < CH_IN; in_ch = in_ch + 1) begin : MAC_IN_LOOP
          mac_3x3 #(.INPUT_IS_SIGNED(0)) u_mac_3x3 (
            .clk(clk),
            .rst_n(rst_n),
            .in_valid(in_valid),
            .win00(m_win00[in_ch]), .win01(m_win01[in_ch]), .win02(m_win02[in_ch]),
            .win10(m_win10[in_ch]), .win11(m_win11[in_ch]), .win12(m_win12[in_ch]),
            .win20(m_win20[in_ch]), .win21(m_win21[in_ch]), .win22(m_win22[in_ch]),
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
    // Sum all input channels for each output channel
    // ============================================================
    generate
      for(out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin : SUM_LOOP
        wire signed [31:0] sum_stage1 [0:3];
        wire signed [31:0] sum_stage2 [0:1];

        assign sum_stage1[0] = out_mac_per_ch[out_ch][0] + out_mac_per_ch[out_ch][1];
        assign sum_stage1[1] = out_mac_per_ch[out_ch][2] + out_mac_per_ch[out_ch][3];
        assign sum_stage1[2] = out_mac_per_ch[out_ch][4] + out_mac_per_ch[out_ch][5];
        assign sum_stage1[3] = out_mac_per_ch[out_ch][6] + out_mac_per_ch[out_ch][7];

        assign sum_stage2[0] = sum_stage1[0] + sum_stage1[1];
        assign sum_stage2[1] = sum_stage1[2] + sum_stage1[3];

        assign out_mac[out_ch] = sum_stage2[0] + sum_stage2[1];
      end
    endgenerate

    // ============================================================
    // Counters
    // ============================================================
    wire need_flush = !in_valid && (row_cnt >= IMG_H && row_cnt <= IMG_H + 1);

    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
          col_cnt <= 0;
          row_cnt <= 0;
      end else if (in_valid || need_flush) begin
          if (col_cnt >= IMG_W - 1) begin
              col_cnt <= 0;
              if (row_cnt == 60)
                  row_cnt <= 0;
              else
                  row_cnt <= row_cnt + 1;
          end else begin
              col_cnt <= col_cnt + 1;
          end
      end
    end

    wire start_output;
    wire valid_range_row = (row_cnt >= 2 && row_cnt <= IMG_H + 1);

    assign start_output = valid_range_row;

    reg [3:0] conv_valid_pipe;
    wire flush_valid = !in_valid &&
                       (row_cnt >= IMG_H && row_cnt <= IMG_H + 1) &&
                       (col_cnt < IMG_W);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) conv_valid_pipe <= 0;
        else begin
          if (in_valid) begin
              conv_valid_pipe <= {conv_valid_pipe[2:0], start_output};
          end else begin
              conv_valid_pipe <= {conv_valid_pipe[2:0], flush_valid};
          end
        end
    end

    // ============================================================
    // Quantization & SELU Integration
    // ============================================================
    wire signed [7:0] selu_in [0:CH_OUT-1];
    wire signed [7:0] selu_out [0:CH_OUT-1];
    wire              selu_out_valid [0:CH_OUT-1];

    generate
      for (out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin : SELU_GEN
        wire signed [31:0] scaled_mac = out_mac[out_ch] >>> QUANT_SHIFT;

        assign selu_in[out_ch] = (scaled_mac > 127)  ? 8'sd127 :
                                 (scaled_mac < -128) ? -8'sd128 :
                                 scaled_mac[7:0];

        selu_lut_act u_selu (
            .clk(clk),
            .rst_n(rst_n),
            .in_valid(conv_valid_pipe[3]),
            .in_data(selu_in[out_ch]),
            .out_valid(selu_out_valid[out_ch]),
            .out_data(selu_out[out_ch])
        );
      end
    endgenerate

    // ============================================================
    // 6. Final Output Assignment
    // ============================================================

    always @(*) begin
      out_valid   = selu_out_valid[0];

      out_conv0   = selu_out[0];
      out_conv1   = selu_out[1];
      out_conv2   = selu_out[2];
      out_conv3   = selu_out[3];
      out_conv4   = selu_out[4];
      out_conv5   = selu_out[5];
      out_conv6   = selu_out[6];
      out_conv7   = selu_out[7];
      out_conv8   = selu_out[8];
      out_conv9   = selu_out[9];
      out_conv10  = selu_out[10];
      out_conv11  = selu_out[11];
      out_conv12  = selu_out[12];
      out_conv13  = selu_out[13];
      out_conv14  = selu_out[14];
      out_conv15  = selu_out[15];
    end

endmodule

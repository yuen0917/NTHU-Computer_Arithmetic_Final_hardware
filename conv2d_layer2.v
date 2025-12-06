// ============================================================
// 2D Convolution Module with 16 channels (8 input channels)
// Input: 8 parallel channels from layer1 output
// Output: 16 channels with SELU activation function
// ============================================================
module conv2d_layer2 #(
  parameter PADDING     = 1,
  parameter IMG_W       = 28,
  parameter IMG_H       = 28,
  parameter CH_IN       = 8,
  parameter CH_OUT      = 16,
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
    // Line Buffers & Window Generators (same as Layer 1)
    // ============================================================
    genvar i;

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
      for(i = 0; i < CH_IN; i = i + 1) begin
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
          .r0(r0[i]),
          .r1(r1[i]),
          .r2(r2[i]),
          .in_valid(in_valid),
          .win00(win00[i]),
          .win01(win01[i]),
          .win02(win02[i]),
          .win10(win10[i]),
          .win11(win11[i]),
          .win12(win12[i]),
          .win20(win20[i]),
          .win21(win21[i]),
          .win22(win22[i])
        );
      end
    endgenerate

    // ============================================================
    // MAC Units for each output channel
    // ============================================================
    // MAC outputs for each input channel and output channel
    // out_mac_per_ch[output_channel][input_channel]
    wire signed [31:0] out_mac_per_ch [0:CH_OUT-1][0:CH_IN-1];

    // Final MAC output for each output channel (sum of all input channels)
    wire signed [31:0] out_mac [0:CH_OUT-1];

    genvar out_ch, in_ch;
    generate
      // For each output channel
      for(out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin
        // For each input channel
        for(in_ch = 0; in_ch < CH_IN; in_ch = in_ch + 1) begin
          mac_3x3 u_mac_3x3 (
            .clk(clk),
            .rst_n(rst_n),
            .in_valid(in_valid),
            .win00(win00[in_ch]), .win01(win01[in_ch]), .win02(win02[in_ch]),
            .win10(win10[in_ch]), .win11(win11[in_ch]), .win12(win12[in_ch]),
            .win20(win20[in_ch]), .win21(win21[in_ch]), .win22(win22[in_ch]),
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
    // Using generate to create adder tree for better synthesis
    // ============================================================
    generate
      for(out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin
        // Create adder tree: sum all CH_IN channels
        // For 8 channels, we can do: ((ch0+ch1)+(ch2+ch3)) + ((ch4+ch5)+(ch6+ch7))
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
    // for window valid signal (correction counter logic)
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
          col_cnt <= 0;
          row_cnt <= 0;
      end else if (in_valid) begin
          // correction: here must use TOTAL_W to judge the line change, because the input stream contains Padding
          if (col_cnt == TOTAL_W - 1) begin
              col_cnt <= 0;
              // correction: Row must also count to TOTAL_H (including Padding rows)
              row_cnt <= (row_cnt == TOTAL_H - 1) ? 0 : row_cnt + 1;
          end else begin
              col_cnt <= col_cnt + 1;
          end
      end
    end

    // ============================================================
    // Window valid signal (similar to layer1)
    // ============================================================
    wire [COL_CNT_W:0] next_col_cnt;
    assign next_col_cnt = (col_cnt == TOTAL_W - 1) ? 0 : col_cnt + 1;

    wire col_valid_region;
    wire row_valid_region;
    wire input_region_valid;

    // 1. use next_col_cnt to ensure that the Valid and the data output of the Line Buffer are synchronized
    //    so that the Valid will be High when the first piece of data comes in
    assign col_valid_region = (next_col_cnt >= PADDING) && (next_col_cnt < IMG_W + PADDING);

    // Row keep the original (because the update of Row is slower, and the TB behavior has verified that Row is correct)
    assign row_valid_region = (row_cnt >= 1) && (row_cnt <= IMG_H);

    assign input_region_valid = row_valid_region && col_valid_region;

    // ============================================================
    // Pipeline Compensation (Stage 1: Conv Latency)
    // ============================================================
    // The latency of the convolution: LB(1) + Win(1) + MAC(1) + Adder(0) = 3 cycles (Data Ready)
    // We need to send conv_valid to the SELU module at the correct time
    // Note: Layer 1 uses [4] because it includes Output Reg.
    // Here we send the data to SELU before it enters the Output Reg.
    // Data Path: Input -> LB(T1) -> Win(T2) -> MAC/Adder(T3) -> Quantize -> SELU
    // So we need to delay 3 cycles for the input valid of SELU

    reg [3:0] conv_valid_pipe; // use 4 bit for safety
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) conv_valid_pipe <= 0;
      else if (in_valid) conv_valid_pipe <= {conv_valid_pipe[2:0], input_region_valid};
      else conv_valid_pipe <= {conv_valid_pipe[2:0], 1'b0};
    end

    // This is the Valid signal to send to SELU
    wire valid_to_selu = conv_valid_pipe[2];

    // ============================================================
    // Quantization & SELU Integration
    // ============================================================
    wire signed [7:0] selu_in [0:CH_OUT-1];
    wire signed [7:0] selu_out [0:CH_OUT-1];
    wire              selu_out_valid [0:CH_OUT-1]; // each channel has valid, theoretically the same

    generate
      for (out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin : SELU_GEN
        // Quantization (32-bit -> 8-bit)
        // Note: SELU LUT accepts signed 8-bit (-128 ~ 127)
        // Here we need to do Clipping to prevent overflow
        wire signed [31:0] scaled_mac = out_mac[out_ch] >>> QUANT_SHIFT;

        assign selu_in[out_ch] = (scaled_mac > 127)  ? 8'sd127 :
                                 (scaled_mac < -128) ? -8'sd128 :
                                 scaled_mac[7:0];

        // Instantiate SELU LUT
        selu_lut_act u_selu (
            .clk(clk),
            .rst_n(rst_n),
            .in_valid(valid_to_selu),
            .in_data(selu_in[out_ch]),
            .out_valid(selu_out_valid[out_ch]),
            .out_data(selu_out[out_ch])
        );
      end
    endgenerate

    // ============================================================
    // 6. Final Output Assignment
    // ============================================================
    // Directly connect the SELU output to the module output
    // Because SELU has an Output Register inside, so here is wire connection

    always @(*) begin
      // Only need to look at the Valid of the 0th channel, because all channels are synchronized
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
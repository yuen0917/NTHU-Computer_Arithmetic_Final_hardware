// ------------------------------------------------------------
// 2D Convolution Module with 16 channels (8 input channels)
// Input: 8 parallel channels from layer1 output
// Output: 16 channels with SELU activation function
// ------------------------------------------------------------
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

    genvar i;
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
      end
    endgenerate

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

    // MAC outputs for each input channel and output channel
    // out_mac_per_ch[output_channel][input_channel]
    wire signed [31:0] out_mac_per_ch [0:CH_OUT-1][0:CH_IN-1];

    // Final MAC output for each output channel (sum of all input channels)
    wire signed [31:0] out_mac [0:CH_OUT-1];

    // ------------------------------------------------------------
    // MAC units: For each output channel, we need CH_IN mac_3x3 units
    // Weight indexing: weight_data[(out_ch * CH_IN + in_ch) * KERNEL_SIZE + kernel_pos]
    // ------------------------------------------------------------
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

    // ------------------------------------------------------------
    // Sum all input channels for each output channel
    // Using generate to create adder tree for better synthesis
    // ------------------------------------------------------------
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

    // ------------------------------------------------------------
    // Window valid signal (similar to layer1)
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        col_cnt <= 0;
        row_cnt <= 0;
      end else if (in_valid) begin
        if (col_cnt == TOTAL_W - 1) begin
          col_cnt <= 0;
          row_cnt <= (row_cnt == TOTAL_H - 1) ? 0 : row_cnt + 1;
        end else begin
          col_cnt <= col_cnt + 1;
        end
      end
    end

    wire col_valid_region;
    wire row_valid_region;
    wire input_region_valid;

    assign col_valid_region = (col_cnt >= 1) && (col_cnt <= IMG_W);
    assign row_valid_region = (row_cnt >= 1) && (row_cnt <= IMG_H);
    assign input_region_valid = row_valid_region && col_valid_region;

    // Pipeline delay compensation (4 cycles)
    reg [3:0] valid_pipe;
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        valid_pipe <= 0;
      end else if (in_valid) begin
        valid_pipe <= {valid_pipe[2:0], input_region_valid};
      end else begin
        valid_pipe <= {valid_pipe[2:0], 1'b0};
      end
    end

    // ------------------------------------------------------------
    // Quantization and SELU activation
    // ------------------------------------------------------------
    wire signed [31:0] tmp_mac [0:CH_OUT - 1];
    reg         [ 7:0] sat_val [0:CH_OUT - 1];

    // Quantization shift
    generate
      for (out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin
        assign tmp_mac[out_ch] = (out_mac[out_ch] > 0) ? out_mac[out_ch] >>> QUANT_SHIFT : 0;
      end
    endgenerate

    // TODO: Implement SELU activation function
    // SELU(x) = { λx        if x > 0
    //           { λα(e^x - 1) if x ≤ 0
    // where λ ≈ 1.0507, α ≈ 1.6733
    // For now, using ReLU-like behavior (only positive values)

    // ------------------------------------------------------------
    // Output assignment
    // ------------------------------------------------------------
    integer k;
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        out_valid <= 1'b0;
        out_conv0  <= 0;
        out_conv1  <= 0;
        out_conv2  <= 0;
        out_conv3  <= 0;
        out_conv4  <= 0;
        out_conv5  <= 0;
        out_conv6  <= 0;
        out_conv7  <= 0;
        out_conv8  <= 0;
        out_conv9  <= 0;
        out_conv10 <= 0;
        out_conv11 <= 0;
        out_conv12 <= 0;
        out_conv13 <= 0;
        out_conv14 <= 0;
        out_conv15 <= 0;
      end else if (in_valid) begin
        // Saturation
        for (k = 0; k < CH_OUT; k = k + 1) begin
          sat_val[k] = (tmp_mac[k] > 255) ? 255 : tmp_mac[k][7:0];
        end

        out_valid <= valid_pipe[3];

        if (valid_pipe[3]) begin
          out_conv0  <= sat_val[0];
          out_conv1  <= sat_val[1];
          out_conv2  <= sat_val[2];
          out_conv3  <= sat_val[3];
          out_conv4  <= sat_val[4];
          out_conv5  <= sat_val[5];
          out_conv6  <= sat_val[6];
          out_conv7  <= sat_val[7];
          out_conv8  <= sat_val[8];
          out_conv9  <= sat_val[9];
          out_conv10 <= sat_val[10];
          out_conv11 <= sat_val[11];
          out_conv12 <= sat_val[12];
          out_conv13 <= sat_val[13];
          out_conv14 <= sat_val[14];
          out_conv15 <= sat_val[15];
        end
      end else begin
        out_valid <= 1'b0;
      end
    end

endmodule
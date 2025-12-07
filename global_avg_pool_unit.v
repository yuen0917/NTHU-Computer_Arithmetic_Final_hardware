`timescale 1ns/1ps
// ============================================================
// Global Average Pooling Unit
// ============================================================
module global_avg_pool_unit #(
  parameter IMG_W = 14,
  parameter IMG_H = 14
)(
  input            clk,
  input            rst_n,
  input      [7:0] in_data,
  input            in_valid,
  output reg [7:0] out_data,
  output reg       out_valid
);
  localparam TOTAL_PIXELS = IMG_W * IMG_H;

  // max value = 255 (8-bit max) * 196 = 49980
  // 49980 < 65535 = 2^16
  reg  [15:0] sum_acc;
  reg  [ 7:0] pixel_cnt;

  wire [15:0] current_sum;
  assign current_sum = sum_acc + in_data;


  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum_acc   <= 0;
      pixel_cnt <= 0;
      out_data  <= 0;
      out_valid <= 0;
    end else if (in_valid) begin
      if (pixel_cnt == TOTAL_PIXELS - 1) begin
        // out_data  <= current_sum/TOTAL_PIXELS;
        out_data  <= (current_sum * 24'd167) >> 15;
        out_valid <= 1;
        pixel_cnt <= 0;
        sum_acc   <= 0;
      end else begin
        pixel_cnt <= pixel_cnt + 1;
        sum_acc   <= sum_acc + in_data;
        out_valid <= 0;
      end
    end else begin
      out_valid <= 0;
    end
  end
endmodule
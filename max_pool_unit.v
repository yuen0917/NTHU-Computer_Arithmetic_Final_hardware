`timescale 1ns/1ps

// ============================================================
// Max Pooling Module
// ============================================================
module max_pool_unit #(
    parameter IMG_W = 28,
    parameter IMG_H = 28
)(
    input            clk,
    input            rst_n,
    input            in_valid,
    input      [7:0] in_data,
    output reg       out_valid,
    output reg [7:0] out_data
);
    localparam HALF_IMG_W = IMG_W >> 1;
    localparam MAX_PIXEL  = IMG_W * IMG_H - 1;

    reg [7:0] tmp_in_data;
    reg [7:0] row_buf [0:HALF_IMG_W - 1];

    reg [3:0] buf_cnt;

    reg [4:0] row_idx;
    reg [4:0] col_idx;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      col_idx   <= 0;
      row_idx   <= 0;
    end else if (in_valid) begin
      // row and col counter
      // col_idx = pixel_cnt % IMG_W
      // row_idx = pixel_cnt / IMG_W
      if (col_idx == IMG_W - 1) begin
        col_idx <= 0;
        if (row_idx == IMG_H - 1) begin
          row_idx <= 0;
        end else begin
          row_idx <= row_idx + 1;
        end
      end else begin
        col_idx <= col_idx + 1;
      end
    end
  end

  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      buf_cnt   <= 0;
      out_valid <= 0;
      out_data  <= 0;
      for(i = 0; i < HALF_IMG_W; i = i + 1)begin
        row_buf[i] <= 0;
      end
    end else if (in_valid) begin
      // update buffer counter when col_idx is odd.
      if (col_idx == IMG_W - 1) begin
        buf_cnt <= 0;
      end else if (col_idx[0] == 1) begin
        buf_cnt <= buf_cnt + 1;
      end

      // if in row0, and col_idx is even => put in_data into tmp_in_data.
      // if in row0, and col_idx is odd  => put the max(in_data, tmp_in_data) into row_buf.
      // if in row1, and col_idx is even => put the max(in_data, row_buf) into row_buf.
      // if in row1, and col_idx is odd  => put the max(in_data, row_buf) into out_data.
      if (row_idx[0] == 0) begin // row0
        out_valid          <= 0;
        if (col_idx[0] == 0) begin
          tmp_in_data      <= in_data;
        end else begin
          row_buf[buf_cnt] <= (tmp_in_data > in_data) ? tmp_in_data : in_data;
        end
      end else begin // row1
        if (col_idx[0] == 0) begin
          row_buf[buf_cnt] <= (row_buf[buf_cnt] > in_data) ? row_buf[buf_cnt] : in_data;
          out_valid        <= 0;
        end else begin
          out_data         <= (row_buf[buf_cnt] > in_data) ? row_buf[buf_cnt] : in_data;
          out_valid        <= 1;
        end
      end
    end else begin
      out_valid <= 0;
    end
  end

endmodule
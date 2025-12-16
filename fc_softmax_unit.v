`timescale 1ns/1ps
// ============================================================
// FC & Softmax Unit
// ============================================================
module fc_softmax_unit #(
  parameter IN_DIM  = 32,
  parameter OUT_DIM = 10
)(
  input                    clk,
  input                    rst_n,
  input             [ 7:0] in_data,
  input                    in_valid,
  output reg signed [31:0] out_data,
  output reg               out_valid,
  output reg        [ 3:0] class_out,
  output reg signed [31:0] class_value,
  output reg               class_valid
);
  localparam W_SIZE = IN_DIM * OUT_DIM;
  localparam B_SIZE = OUT_DIM;

  localparam S_IDLE     = 0;
  localparam S_ACC      = 1;
  localparam S_FIND_MAX = 2;

  //------------------------------------------
  // load weights and biases
  //------------------------------------------
  reg signed [ 7:0] weights [0:W_SIZE - 1];
  reg signed [31:0] biases  [0:B_SIZE - 1];

  initial begin
    $readmemh("fc_weights.txt", weights);
    $readmemh("fc_biases.txt", biases);
  end


  reg signed [31:0] acc [0:OUT_DIM - 1];
  reg        [ 5:0] acc_cnt;
  reg        [ 3:0] out_cnt;


  reg signed [31:0] max_val;

  reg [1:0] state;
  reg [1:0] next_state;

  always @(*) begin
    case(state)
      S_IDLE:     next_state = (in_valid) ? S_ACC : S_IDLE;
      S_ACC:      next_state = (in_valid && acc_cnt == (IN_DIM - 1)) ? S_FIND_MAX : S_ACC;
      S_FIND_MAX: next_state = (out_cnt == (OUT_DIM - 1)) ? S_IDLE : S_FIND_MAX;
      default:    next_state = S_IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_cnt     <= 0;
      out_data    <= 0;
      out_valid   <= 0;
      out_cnt     <= 0;
      class_out   <= 0;
      class_valid <= 0;
      class_value <= 0;
      max_val     <= 0;
      for(i = 0; i < OUT_DIM; i = i + 1) acc[i] <= 0;
    end else begin
      case(state)
        S_IDLE: begin
          acc_cnt     <= 0;
          out_data    <= 0;
          out_valid   <= 0;
          out_cnt     <= 0;
          class_out   <= 0;
          class_valid <= 0;
          class_value <= 0;
          max_val     <= 0;

          for(i = 0; i < OUT_DIM; i = i + 1) acc[i] <= 0;

          // for bias and first in_data
          if (in_valid) begin
            for (i = 0; i < OUT_DIM; i = i + 1) begin
              acc[i] <= biases[i] + ($signed({in_data}) * weights[i*32 + 0]);
            end
            acc_cnt <= 1;
          end
        end
        S_ACC: begin
          if (in_valid) begin
            for (i = 0; i < OUT_DIM; i = i + 1) begin
              acc[i] <= acc[i] + ($signed({in_data}) * weights[i*32 + acc_cnt]);
            end

            if (acc_cnt == IN_DIM - 1) begin
              acc_cnt <= 0;
            end else begin
              acc_cnt <= acc_cnt + 1;
            end
          end
        end
        S_FIND_MAX: begin
          out_valid <= 1;
          out_data  <= acc[out_cnt];

          if (out_cnt == 0) begin
            max_val     <= acc[0];
            class_out   <= 0;
          end else begin
            if (acc[out_cnt] > max_val) begin
              max_val   <= acc[out_cnt];
              class_out <= out_cnt;

            end
          end

          if (out_cnt == OUT_DIM - 1) begin
            out_cnt     <= 0;
            class_valid <= 1;
            class_value <= max_val;
          end else begin
            out_cnt     <= out_cnt + 1;
            class_value <= max_val;
          end
        end
        default: begin
          acc_cnt     <= 0;
          out_data    <= 0;
          out_valid   <= 0;
          out_cnt     <= 0;
          class_out   <= 0;
          class_valid <= 0;
          class_value <= 0;
          max_val     <= 0;
          for(i = 0; i < OUT_DIM; i = i + 1) acc[i] <= 0;
        end
      endcase
    end
  end
endmodule

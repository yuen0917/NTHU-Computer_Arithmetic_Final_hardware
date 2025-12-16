`timescale 1ns/1ps

// ============================================================
// SELU LUT Activation Function
// ============================================================
module selu_lut_act (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              in_valid,
    input  wire signed [7:0] in_data,   // Quantized int8 input
    output reg               out_valid,
    output reg  signed [7:0] out_data    // SELU output
);

    reg signed [7:0] selu_lut [0:255];

    initial begin
        $readmemh("selu_lut.txt", selu_lut);
    end

    wire [7:0] idx;
    assign idx = in_data;

    reg signed [7:0] lut_out;
    reg              valid_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lut_out   <= 0;
            out_data  <= 0;
            valid_d1  <= 0;
            out_valid <= 0;
        end else begin
            if (in_valid) begin
                lut_out <= selu_lut[idx];
            end
            valid_d1  <= in_valid;

            out_data  <= lut_out;
            out_valid <= valid_d1;
        end
    end

endmodule
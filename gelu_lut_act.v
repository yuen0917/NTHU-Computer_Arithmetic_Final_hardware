`timescale 1ns/1ps
// ============================================================
// GELU LUT Activation Function
// ============================================================
module gelu_lut_act (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              in_valid,
    input  wire signed [7:0] in_data,
    output reg               out_valid,
    output reg  signed [7:0] out_data
);

    reg signed [7:0] gelu_table [0:255];

    initial begin
        $readmemh("gelu_lut.txt", gelu_table);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_data  <= 8'd0;
        end else if (in_valid) begin
            out_valid <= 1'b1;
            out_data  <= gelu_table[$unsigned(in_data)];
        end else begin
            out_valid <= 1'b0;
        end
    end

endmodule
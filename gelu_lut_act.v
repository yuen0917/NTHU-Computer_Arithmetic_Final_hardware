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

    // Declare 256 8-bit memory spaces
    reg signed [7:0] gelu_table [0:255];

    // Initialization: Read the pre-calculated GELU values
    initial begin
        // $readmemh("import_file/gelu_lut.txt", gelu_table);
        $readmemh("gelu_lut.txt", gelu_table);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_data  <= 8'd0;
        end else if (in_valid) begin
            out_valid <= 1'b1;
            // Treat the input data as an address to look up the table
            // in_data is -128 ~ 127, directly as an index corresponding to Verilog's 0~255 (2's complement)
            out_data  <= gelu_table[in_data];
        end else begin
            out_valid <= 1'b0;
        end
    end

endmodule
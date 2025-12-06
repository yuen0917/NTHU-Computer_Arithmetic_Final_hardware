module selu_lut_act (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              in_valid,
    input  wire signed [7:0] in_data,   // Quantized int8 input
    output reg               out_valid,
    output reg  signed [7:0] out_data    // SELU output
);

    // 256-entry LUT
    reg signed [7:0] selu_lut [0:255];

    initial begin
        $readmemh("selu_lut.txt", selu_lut);
    end

    // Index conversion: signed 8-bit (-128 ~ 127) to unsigned index (0 ~ 255)
    // Mapping: in_data = -128 → idx = 128, in_data = -1 → idx = 255, in_data = 0 → idx = 0, in_data = 127 → idx = 127
    // This allows using a 256-entry LUT to cover all possible 8-bit input values
    wire [7:0] idx;
    assign idx = in_data;  // Bit pattern preserved, interpreted as unsigned for indexing

    reg signed [7:0] lut_out;
    reg              valid_d1; // used to delay the Valid signal

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lut_out   <= 0;
            out_data  <= 0;
            valid_d1  <= 0;
            out_valid <= 0;
        end else begin
            // Stage 1: Read Memory
            if (in_valid) begin
                lut_out <= selu_lut[idx];
            end
            valid_d1  <= in_valid; // Valid follows the Data first stage

            // Stage 2: Output Register
            out_data  <= lut_out;
            out_valid <= valid_d1; // Valid follows the Data second stage (total delay 2 clk)
        end
    end

endmodule
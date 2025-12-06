module selu_lut_act (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              in_valid,
    input  wire signed [7:0] in_data,   // int8 輸入
    output reg               out_valid,
    output reg  signed [7:0] out_data   // int8 輸出 (SELU)
);

    // 256-entry LUT：對應 x ∈ [-128..127]
    reg signed [7:0] selu_lut [0:255];

    initial begin
        $readmemh("selu_lut.hex", selu_lut);
    end

    // 把 signed 8-bit 重新解讀成 unsigned index：0..255
    wire [7:0] idx;
    assign idx = in_data;  // 同一組 bits，當 unsigned 用即可

    reg signed [7:0] lut_out;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lut_out   <= 0;
            out_data  <= 0;
            out_valid <= 0;
        end else begin
            // 一拍讀 LUT
            if (in_valid) begin
                lut_out <= selu_lut[idx];
            end

            // 再一拍輸出（簡單 pipeline）
            out_data  <= lut_out;
            out_valid <= in_valid;  // 或者延遲一拍視你 pipeline 設計
        end
    end

endmodule

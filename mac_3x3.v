`timescale 1ns/1ps
// ============================================================
// 3x3 Window MAC Unit
// ============================================================
module mac_3x3 #(
    parameter INPUT_IS_SIGNED = 0
)(
    input                    clk,
    input                    rst_n,
    input                    in_valid,
    input             [ 7:0] win00, win01, win02,
    input             [ 7:0] win10, win11, win12,
    input             [ 7:0] win20, win21, win22,
    input      signed [ 7:0] weight00, weight01, weight02,
    input      signed [ 7:0] weight10, weight11, weight12,
    input      signed [ 7:0] weight20, weight21, weight22,
    output reg signed [31:0] out_mac
);

    wire signed [31:0] mac00, mac01, mac02, mac10, mac11, mac12, mac20, mac21, mac22;
    wire signed [31:0] mac0, mac1, mac2;

    function signed [16:0] to_signed_input;
        input [7:0] val;
        begin
            if (INPUT_IS_SIGNED)
                to_signed_input = $signed(val);      // -2 (254) -> -2
            else
                to_signed_input = $signed({1'b0, val}); // 254 -> +254
        end
    endfunction

    assign mac00 = to_signed_input(win00) * $signed(weight00);
    assign mac01 = to_signed_input(win01) * $signed(weight01);
    assign mac02 = to_signed_input(win02) * $signed(weight02);
    assign mac10 = to_signed_input(win10) * $signed(weight10);
    assign mac11 = to_signed_input(win11) * $signed(weight11);
    assign mac12 = to_signed_input(win12) * $signed(weight12);
    assign mac20 = to_signed_input(win20) * $signed(weight20);
    assign mac21 = to_signed_input(win21) * $signed(weight21);
    assign mac22 = to_signed_input(win22) * $signed(weight22);

    assign mac0 = mac00 + mac01 + mac02;
    assign mac1 = mac10 + mac11 + mac12;
    assign mac2 = mac20 + mac21 + mac22;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_mac <= 0;
        end else if (in_valid) begin
            out_mac <= mac0 + mac1 + mac2;
        end
    end

endmodule
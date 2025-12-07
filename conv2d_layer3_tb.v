`timescale 1ns/1ps
// ============================================================
// Conv2d Layer 3 Testbench
// ============================================================
module conv2d_layer3_tb;

    // ============================================================
    // 1. Parameters and Constants
    // ============================================================
    parameter PADDING       = 1;
    parameter IMG_W         = 14; // Layer 3 Input is 14x14
    parameter IMG_H         = 14;
    parameter CH_IN         = 16; // 16 Input Channels
    parameter CH_OUT        = 32; // 32 Output Channels
    parameter QUANT_SHIFT   = 10;

    // Calculated total size with padding (14 + 2 = 16)
    localparam TOTAL_W      = IMG_W + 2 * PADDING;
    localparam TOTAL_H      = IMG_H + 2 * PADDING;

    // Weight file name
    parameter W_FILE = "conv3_gelu.txt";

    // ============================================================
    // 2. Signals Declaration
    // ============================================================
    reg          clk;
    reg          rst_n;
    reg          in_valid;

    // 16 input channels
    reg  [7:0]   in_data [0:CH_IN-1];

    // 32 output channels
    wire         out_valid;
    wire [7:0]   out_conv [0:31];

    // Connect DUT's wire to array wire for easier access
    wire [7:0]   dut_out_wire [0:31];

    // Assign DUT outputs to array
    // Using a loop in generate block would be cleaner but for TB explicit assignment is fine
    // or just use the wire array directly in DUT instantiation
    assign out_conv[0]  = dut_out_wire[0];  assign out_conv[1]  = dut_out_wire[1];
    assign out_conv[2]  = dut_out_wire[2];  assign out_conv[3]  = dut_out_wire[3];
    assign out_conv[4]  = dut_out_wire[4];  assign out_conv[5]  = dut_out_wire[5];
    assign out_conv[6]  = dut_out_wire[6];  assign out_conv[7]  = dut_out_wire[7];
    assign out_conv[8]  = dut_out_wire[8];  assign out_conv[9]  = dut_out_wire[9];
    assign out_conv[10] = dut_out_wire[10]; assign out_conv[11] = dut_out_wire[11];
    assign out_conv[12] = dut_out_wire[12]; assign out_conv[13] = dut_out_wire[13];
    assign out_conv[14] = dut_out_wire[14]; assign out_conv[15] = dut_out_wire[15];
    assign out_conv[16] = dut_out_wire[16]; assign out_conv[17] = dut_out_wire[17];
    assign out_conv[18] = dut_out_wire[18]; assign out_conv[19] = dut_out_wire[19];
    assign out_conv[20] = dut_out_wire[20]; assign out_conv[21] = dut_out_wire[21];
    assign out_conv[22] = dut_out_wire[22]; assign out_conv[23] = dut_out_wire[23];
    assign out_conv[24] = dut_out_wire[24]; assign out_conv[25] = dut_out_wire[25];
    assign out_conv[26] = dut_out_wire[26]; assign out_conv[27] = dut_out_wire[27];
    assign out_conv[28] = dut_out_wire[28]; assign out_conv[29] = dut_out_wire[29];
    assign out_conv[30] = dut_out_wire[30]; assign out_conv[31] = dut_out_wire[31];

    // TB memory
    reg  [7:0]   input_img [0:CH_IN-1][0:IMG_H-1][0:IMG_W-1];
    reg  signed [7:0]   weights   [0:CH_OUT-1][0:CH_IN-1][0:2][0:2];
    reg  signed [7:0]   golden_out[0:CH_OUT-1][0:IMG_H-1][0:IMG_W-1];

    integer i, j, ch, r, c, k_r, k_c, o_ch, i_ch;
    integer file_handle;
    integer err_cnt;
    integer out_pixel_cnt;
    integer diff;

    // ============================================================
    // 3. DUT Instance
    // ============================================================
    conv2d_layer3 #(
        .PADDING(PADDING),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .CH_IN(CH_IN),
        .CH_OUT(CH_OUT),
        .QUANT_SHIFT(QUANT_SHIFT)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        // Connect 16 Inputs
        .in_data0(in_data[0]),   .in_data1(in_data[1]),   .in_data2(in_data[2]),   .in_data3(in_data[3]),
        .in_data4(in_data[4]),   .in_data5(in_data[5]),   .in_data6(in_data[6]),   .in_data7(in_data[7]),
        .in_data8(in_data[8]),   .in_data9(in_data[9]),   .in_data10(in_data[10]), .in_data11(in_data[11]),
        .in_data12(in_data[12]), .in_data13(in_data[13]), .in_data14(in_data[14]), .in_data15(in_data[15]),

        .out_valid(out_valid),
        // Connect 32 Outputs
        .out_conv0(dut_out_wire[0]),   .out_conv1(dut_out_wire[1]),   .out_conv2(dut_out_wire[2]),   .out_conv3(dut_out_wire[3]),
        .out_conv4(dut_out_wire[4]),   .out_conv5(dut_out_wire[5]),   .out_conv6(dut_out_wire[6]),   .out_conv7(dut_out_wire[7]),
        .out_conv8(dut_out_wire[8]),   .out_conv9(dut_out_wire[9]),   .out_conv10(dut_out_wire[10]), .out_conv11(dut_out_wire[11]),
        .out_conv12(dut_out_wire[12]), .out_conv13(dut_out_wire[13]), .out_conv14(dut_out_wire[14]), .out_conv15(dut_out_wire[15]),
        .out_conv16(dut_out_wire[16]), .out_conv17(dut_out_wire[17]), .out_conv18(dut_out_wire[18]), .out_conv19(dut_out_wire[19]),
        .out_conv20(dut_out_wire[20]), .out_conv21(dut_out_wire[21]), .out_conv22(dut_out_wire[22]), .out_conv23(dut_out_wire[23]),
        .out_conv24(dut_out_wire[24]), .out_conv25(dut_out_wire[25]), .out_conv26(dut_out_wire[26]), .out_conv27(dut_out_wire[27]),
        .out_conv28(dut_out_wire[28]), .out_conv29(dut_out_wire[29]), .out_conv30(dut_out_wire[30]), .out_conv31(dut_out_wire[31])
    );

    // ============================================================
    // 4. Clock Generation
    // ============================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // 5. Initialization
    // ============================================================
    initial begin
        $display("==================================================");
        $display("  Start Simulation - Layer 3 (GELU) ");
        $display("==================================================");

        // --- 1. Generate weight file ---
        file_handle = $fopen(W_FILE, "w");
        if (file_handle == 0) begin
            $display("[ERROR] Cannot open %s", W_FILE);
            $finish;
        end

        // Loops updated for CH_OUT=32, CH_IN=16
        for (o_ch = 0; o_ch < CH_OUT; o_ch = o_ch + 1) begin
            for (i_ch = 0; i_ch < CH_IN; i_ch = i_ch + 1) begin
                for (r = 0; r < 3; r = r + 1) begin
                    for (c = 0; c < 3; c = c + 1) begin
                        weights[o_ch][i_ch][r][c] = ($random % 21) - 10;
                        $fdisplay(file_handle, "%h", weights[o_ch][i_ch][r][c]);
                    end
                end
            end
        end
        $fclose(file_handle);
        $display("[TB] Generated %s", W_FILE);

        // --- 2. Backdoor Load Weights ---
        $readmemh(W_FILE, u_dut.weight_data);

        // --- 3. Generate Input Image ---
        for (ch = 0; ch < CH_IN; ch = ch + 1) begin
            for (r = 0; r < IMG_H; r = r + 1) begin
                for (c = 0; c < IMG_W; c = c + 1) begin
                    input_img[ch][r][c] = $random % 256;
                end
            end
        end

        // --- 4. Calculate Golden Output ---
        calculate_golden();

        // --- 5. Start Simulation ---
        rst_n = 1;
        in_valid = 0;
        err_cnt = 0;
        out_pixel_cnt = 0;
        for (i = 0; i < CH_IN; i = i + 1) in_data[i] = 0;

        #20 rst_n = 0;
        #20 rst_n = 1;
        #10;

        $display("[TB] Start Streaming Data (Size 14x14)...");

        in_valid = 1;

        for (r = 0; r < IMG_H; r = r + 1) begin
            for (c = 0; c < IMG_W; c = c + 1) begin
                for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                    in_data[ch] = input_img[ch][r][c];
                end
                @(posedge clk);
            end
        end
        $display("[TB] Flushing Pipeline (Sending Dummy Rows)...");

        for (i = 0; i < CH_IN; i = i + 1) in_data[i] = 0;

        repeat(IMG_W * 2 + 1) @(posedge clk);

        in_valid = 0;

        #2000;

        if (err_cnt == 0 && out_pixel_cnt >= IMG_W * IMG_H) begin
            $display("==================================================");
            $display("  ALL PASS! All %0d pixels passed!", out_pixel_cnt);
            $display("==================================================");
        end else begin
            $display("==================================================");
            $display("  FAIL! Found %0d errors. Output count: %0d", err_cnt, out_pixel_cnt);
            $display("==================================================");
        end

        $finish;
    end

    // ============================================================
    // 6. Output Check
    // ============================================================
    integer check_r = 0;
    integer check_c = 0;

    always @(posedge clk) begin
        if (out_valid) begin
            for (o_ch = 0; o_ch < CH_OUT; o_ch = o_ch + 1) begin
                if (dut_out_wire[o_ch] !== golden_out[o_ch][check_r][check_c]) begin
                    diff = dut_out_wire[o_ch] - golden_out[o_ch][check_r][check_c];
                    // GELU LUT tolerance
                    if (diff < -1 || diff > 1) begin
                        $display("[ERROR] @(%0d,%0d) CH%0d | Exp: %d | Act: %d",
                                 check_r, check_c, o_ch,
                                 golden_out[o_ch][check_r][check_c], dut_out_wire[o_ch]);
                        err_cnt = err_cnt + 1;
                    end
                end
            end

            out_pixel_cnt = out_pixel_cnt + 1;

            if (check_c == IMG_W - 1) begin
                check_c = 0;
                if (check_r == IMG_H - 1) begin
                    check_r = 0;
                end else begin
                    check_r = check_r + 1;
                end
            end else begin
                check_c = check_c + 1;
            end
        end
    end

    // ============================================================
    // 7. Golden Model Task (Includes GELU)
    // ============================================================
    task calculate_golden;
        reg signed [31:0] sum;
        reg signed [31:0] mac_val;
        integer pad_r, pad_c;
        reg signed [31:0] pixel_val;

        begin
            $display("[TB] Calculating Golden Model...");
            for (o_ch = 0; o_ch < CH_OUT; o_ch = o_ch + 1) begin
                for (r = 0; r < IMG_H; r = r + 1) begin
                    for (c = 0; c < IMG_W; c = c + 1) begin

                        sum = 0;
                        for (i_ch = 0; i_ch < CH_IN; i_ch = i_ch + 1) begin
                            for (k_r = 0; k_r < 3; k_r = k_r + 1) begin
                                for (k_c = 0; k_c < 3; k_c = k_c + 1) begin
                                    pad_r = r + k_r - 1;
                                    pad_c = c + k_c - 1;

                                    if (pad_r < 0 || pad_r >= IMG_H || pad_c < 0 || pad_c >= IMG_W) begin
                                        pixel_val = 0;
                                    end else begin
                                        pixel_val = {24'd0, input_img[i_ch][pad_r][pad_c]};
                                    end

                                    mac_val = pixel_val * weights[o_ch][i_ch][k_r][k_c];
                                    sum = sum + mac_val;
                                end
                            end
                        end

                        sum = sum >>> QUANT_SHIFT;
                        if (sum > 127) sum = 127;
                        else if (sum < -128) sum = -128;

                        // GELU Activation
                        golden_out[o_ch][r][c] = gelu_func(sum);
                    end
                end
            end
            $display("[TB] Golden Model Calculation Done.");
        end
    endtask

    // ============================================================
    // 8. GELU Function Simulation (Approximation)
    // Formula: 0.5 * x * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
    // ============================================================
    function signed [7:0] gelu_func;
        input signed [31:0] in_val;
        real x, y;
        real sqrt_2_pi;
        real term;
        real exp_val;
        real tanh_val;
        begin
            sqrt_2_pi = 0.7978845608;
            x = in_val;

            // Calculate inner term
            term = sqrt_2_pi * (x + 0.044715 * x * x * x);

            // Calculate tanh using exp (since some Simulators don't support $tanh)
            // tanh(z) = (exp(2z) - 1) / (exp(2z) + 1)
            // Limit term to avoid overflow in exp
            if (term > 10.0) tanh_val = 1.0;
            else if (term < -10.0) tanh_val = -1.0;
            else begin
                exp_val = $exp(2.0 * term);
                tanh_val = (exp_val - 1.0) / (exp_val + 1.0);
            end

            y = 0.5 * x * (1.0 + tanh_val);

            // Saturation
            if (y > 127.0) gelu_func = 127;
            else if (y < -128.0) gelu_func = -128;
            else gelu_func = $rtoi(y);
        end
    endfunction

endmodule
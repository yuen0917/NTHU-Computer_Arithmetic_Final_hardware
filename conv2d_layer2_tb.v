`timescale 1ns/1ps
// ============================================================
// Conv2d Layer 2 Testbench
// ============================================================
module conv2d_layer2_tb;

    // ============================================================
    // 1. Parameters
    // ============================================================
    parameter PADDING       = 1;
    parameter IMG_W         = 28;
    parameter IMG_H         = 28;
    parameter CH_IN         = 8;
    parameter CH_OUT        = 16;
    parameter QUANT_SHIFT   = 10;

    parameter W_FILE_DUMMY = "conv2_selu.txt";

    // ============================================================
    // 2. Signals Declaration
    // ============================================================
    reg          clk;
    reg          rst_n;
    reg          in_valid;

    // 8 input channels
    reg  [7:0]   in_data [0:CH_IN-1];

    // 16 output channels
    wire         out_valid;
    wire [7:0]   out_conv [0:15];

    wire [7:0]   dut_out_wire [0:15];

    assign out_conv[0]  = dut_out_wire[0];
    assign out_conv[1]  = dut_out_wire[1];
    assign out_conv[2]  = dut_out_wire[2];
    assign out_conv[3]  = dut_out_wire[3];
    assign out_conv[4]  = dut_out_wire[4];
    assign out_conv[5]  = dut_out_wire[5];
    assign out_conv[6]  = dut_out_wire[6];
    assign out_conv[7]  = dut_out_wire[7];
    assign out_conv[8]  = dut_out_wire[8];
    assign out_conv[9]  = dut_out_wire[9];
    assign out_conv[10] = dut_out_wire[10];
    assign out_conv[11] = dut_out_wire[11];
    assign out_conv[12] = dut_out_wire[12];
    assign out_conv[13] = dut_out_wire[13];
    assign out_conv[14] = dut_out_wire[14];
    assign out_conv[15] = dut_out_wire[15];

    reg         [7:0]   input_img [0:CH_IN-1][0:IMG_H*IMG_W-1];
    reg  signed [7:0]   weights   [0:CH_OUT-1][0:CH_IN-1][0:2][0:2];
    reg  signed [7:0]   golden_out[0:CH_OUT-1][0:IMG_H*IMG_W-1];

    integer i, k, ch, r, c, k_r, k_c, o_ch, i_ch;
    integer file_handle;
    integer err_cnt;
    integer out_cnt;
    integer check_r, check_c;
    integer diff;

    // ============================================================
    // 3. DUT Instance
    // ============================================================
    conv2d_layer2 #(
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
        .in_data0(in_data[0]), .in_data1(in_data[1]), .in_data2(in_data[2]), .in_data3(in_data[3]),
        .in_data4(in_data[4]), .in_data5(in_data[5]), .in_data6(in_data[6]), .in_data7(in_data[7]),
        .out_valid(out_valid),
        .out_conv0(dut_out_wire[0]),   .out_conv1(dut_out_wire[1]),   .out_conv2(dut_out_wire[2]),   .out_conv3(dut_out_wire[3]),
        .out_conv4(dut_out_wire[4]),   .out_conv5(dut_out_wire[5]),   .out_conv6(dut_out_wire[6]),   .out_conv7(dut_out_wire[7]),
        .out_conv8(dut_out_wire[8]),   .out_conv9(dut_out_wire[9]),   .out_conv10(dut_out_wire[10]), .out_conv11(dut_out_wire[11]),
        .out_conv12(dut_out_wire[12]), .out_conv13(dut_out_wire[13]), .out_conv14(dut_out_wire[14]), .out_conv15(dut_out_wire[15])
    );

    // ============================================================
    // 4. Clock
    // ============================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // 5. SELU Function
    // ============================================================
    function signed [7:0] selu_func;
        input signed [31:0] in_val;
        real x_float, y_float;
        real lambda;
        real alpha;
        begin
            lambda = 1.0507;
            alpha  = 1.67326;

            if (in_val > 0) begin
                x_float = in_val;
                y_float = lambda * x_float;
                if (y_float > 127.0) selu_func = 127;
                else if (y_float < -128.0) selu_func = -128;
                else selu_func = $rtoi(y_float);
            end else begin
                x_float = in_val;
                y_float = lambda * alpha * ($exp(x_float) - 1.0);

                if (y_float > 127.0) selu_func = 127;
                else if (y_float < -128.0) selu_func = -128;
                else selu_func = $rtoi(y_float);
            end
        end
    endfunction

    // ============================================================
    // 6. Golden Model Task
    // ============================================================
    task calculate_golden;
        reg signed [31:0] sum;
        reg signed [31:0] mac_val;
        reg [7:0] padded_img [0:CH_IN-1][0:IMG_H + 2*PADDING - 1][0:IMG_W + 2*PADDING - 1];
        integer y, x, ky, kx;
        reg signed [31:0] pixel_val;

        begin
            $display("[TB] Calculating Golden Model...");

            for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                for (y = 0; y < IMG_H + 2*PADDING; y = y + 1) begin
                    for (x = 0; x < IMG_W + 2*PADDING; x = x + 1) begin
                        padded_img[ch][y][x] = 0;
                    end
                end
            end

            for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                for (y = 0; y < IMG_H; y = y + 1) begin
                    for (x = 0; x < IMG_W; x = x + 1) begin
                        padded_img[ch][y+PADDING][x+PADDING] = input_img[ch][y*IMG_W + x];
                    end
                end
            end

            for (o_ch = 0; o_ch < CH_OUT; o_ch = o_ch + 1) begin
                for (y = 0; y < IMG_H; y = y + 1) begin
                    for (x = 0; x < IMG_W; x = x + 1) begin

                        sum = 0;
                        for (i_ch = 0; i_ch < CH_IN; i_ch = i_ch + 1) begin
                            for (ky = 0; ky < 3; ky = ky + 1) begin
                                for (kx = 0; kx < 3; kx = kx + 1) begin
                                    pixel_val = {24'd0, padded_img[i_ch][y+ky][x+kx]};
                                    mac_val = pixel_val * weights[o_ch][i_ch][ky][kx];
                                    sum = sum + mac_val;
                                end
                            end
                        end

                        sum = sum >>> QUANT_SHIFT;

                        if (sum > 127) sum = 127;
                        else if (sum < -128) sum = -128;

                        golden_out[o_ch][y*IMG_W + x] = selu_func(sum);
                    end
                end
            end
            $display("[TB] Golden Model Done.");
        end
    endtask

    // ============================================================
    // 7. Main Test Flow
    // ============================================================
    initial begin
        file_handle = $fopen(W_FILE_DUMMY, "w");
        if (file_handle != 0) $fclose(file_handle);

        $display("==================================================");
        $display("  Start Simulation (Layer 2) ");
        $display("==================================================");

        $dumpfile("conv2d_layer2.vcd");
        $dumpvars(0, conv2d_layer2_tb);

        file_handle = $fopen(W_FILE_DUMMY, "w");

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
        $display("[TB] Generated Weight File.");

        for (ch = 0; ch < CH_IN; ch = ch + 1) begin
            for (i = 0; i < IMG_H*IMG_W; i = i + 1) begin
                input_img[ch][i] = $random % 256;
            end
        end

        $readmemh(W_FILE_DUMMY, u_dut.weight_data);

        calculate_golden();

        rst_n = 1;
        in_valid = 0;
        err_cnt = 0;
        out_cnt = 0;
        check_r = 0;
        check_c = 0;
        for (i = 0; i < CH_IN; i = i + 1) in_data[i] = 0;

        #20 rst_n = 0;
        #20 rst_n = 1;
        #20;

        $display("[TB] Start Streaming Data...");
        in_valid = 1;

        @(posedge clk);

        for (r = 0; r < IMG_H; r = r + 1) begin
            for (c = 0; c < IMG_W; c = c + 1) begin
                for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                    in_data[ch] = input_img[ch][r*IMG_W + c];
                end
                @(posedge clk);
            end
        end

        $display("[TB] Flushing Pipeline (Sending Dummy Rows)...");

        for (i = 0; i < CH_IN; i = i + 1) in_data[i] = 0;

        repeat(IMG_W * 2) @(posedge clk);

        in_valid = 0;

        repeat(200) @(posedge clk);

        if (err_cnt == 0) begin
            $display("==================================================");
            $display("  ALL PASS! Checked %0d pixels.", out_cnt);
            $display("==================================================");
        end else begin
            $display("==================================================");
            $display("  FAIL! Found %0d errors.", err_cnt);
            $display("==================================================");
        end

        $finish;
    end

    // ============================================================
    // 8. Output Check (Monitor)
    // ============================================================
    always @(posedge clk) begin
        if (out_valid) begin
            if (out_cnt < IMG_W * IMG_H) begin
                for (o_ch = 0; o_ch < CH_OUT; o_ch = o_ch + 1) begin
                    diff = dut_out_wire[o_ch] - golden_out[o_ch][out_cnt];

                    if (diff < -1 || diff > 1) begin
                        $display("[ERROR] Time=%0t Ch%0d @(r:%0d, c:%0d) | Exp: %d | Act: %d",
                                 $time, o_ch, check_r, check_c,
                                 golden_out[o_ch][out_cnt], dut_out_wire[o_ch]);
                        err_cnt = err_cnt + 1;
                    end
                end
                out_cnt = out_cnt + 1;

                if (check_c == IMG_W - 1) begin
                    check_c = 0;
                    check_r = check_r + 1;
                end else begin
                    check_c = check_c + 1;
                end
            end
        end
    end

endmodule

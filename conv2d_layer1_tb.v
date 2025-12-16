`timescale 1ns/1ps
// ============================================================
// Conv2d Layer 1 Testbench
// ============================================================
module conv2d_layer1_tb;

    // ============================================================
    // 1. Parameters
    // ============================================================
    parameter PADDING     = 1;
    parameter IMG_W       = 28;
    parameter IMG_H       = 28;
    parameter CH_IN       = 1;
    parameter CH_OUT      = 8;

    parameter QUANT_SHIFT = 0;

    parameter W_FILE_DUMMY = "conv1_relu.txt";

    // ============================================================
    // Test Weights Configuration
    // ============================================================
    parameter WEIGHT_CH0 = 1;
    parameter WEIGHT_CH1 = 2;
    parameter WEIGHT_CH2 = 3;
    parameter WEIGHT_CH3 = 4;
    parameter WEIGHT_CH4 = 5;
    parameter WEIGHT_CH5 = 6;
    parameter WEIGHT_CH6 = 7;
    parameter WEIGHT_CH7 = 8;

    reg signed [7:0] test_weights [0:7];

    // ============================================================
    // 2. Signals
    // ============================================================
    reg          clk;
    reg          rst_n;
    reg          in_valid;
    reg  [7:0]   in_data;

    wire         out_valid;
    wire [7:0]   out_conv0;
    wire [7:0]   out_conv1;
    wire [7:0]   out_conv2;
    wire [7:0]   out_conv3;
    wire [7:0]   out_conv4;
    wire [7:0]   out_conv5;
    wire [7:0]   out_conv6;
    wire [7:0]   out_conv7;

    wire [7:0] out_conv_array [0:7];
    assign out_conv_array[0] = out_conv0;
    assign out_conv_array[1] = out_conv1;
    assign out_conv_array[2] = out_conv2;
    assign out_conv_array[3] = out_conv3;
    assign out_conv_array[4] = out_conv4;
    assign out_conv_array[5] = out_conv5;
    assign out_conv_array[6] = out_conv6;
    assign out_conv_array[7] = out_conv7;

    reg  [7:0]   input_img [0:IMG_H*IMG_W-1];
    reg  [7:0]   golden_out [0:CH_OUT-1][0:IMG_H*IMG_W-1];

    integer i, r, c;
    integer out_cnt;
    integer err_cnt;
    integer check_r, check_c;
    integer file_handle;

    // ============================================================
    // 3. DUT Instance
    // ============================================================
    conv2d_layer1 #(
        .PADDING    (PADDING),
        .IMG_W      (IMG_W),
        .IMG_H      (IMG_H),
        .CH_IN      (CH_IN),
        .CH_OUT     (CH_OUT),
        .QUANT_SHIFT(QUANT_SHIFT)
    ) u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .in_valid   (in_valid),
        .in_data    (in_data),
        .out_valid  (out_valid),
        .out_conv0  (out_conv0),
        .out_conv1  (out_conv1),
        .out_conv2  (out_conv2),
        .out_conv3  (out_conv3),
        .out_conv4  (out_conv4),
        .out_conv5  (out_conv5),
        .out_conv6  (out_conv6),
        .out_conv7  (out_conv7)
    );

    // ============================================================
    // 4. Clock Generation
    // ============================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // 5. Weight Setting Task (Backdoor Access)
    // ============================================================
    task set_weights;
        integer ch, pos;
        begin
            $display("[TB] Setting weights via backdoor...");

            for (i = 0; i < u_dut.WEIGHT_SIZE; i = i + 1) begin
                u_dut.weight_data[i] = 0;
            end

            for (ch = 0; ch < CH_OUT; ch = ch + 1) begin
                for (pos = 0; pos < 9; pos = pos + 1) begin
                    u_dut.weight_data[ch * 9 + pos] = test_weights[ch];
                end
                $display("  Channel %0d: Weight set to %0d", ch, test_weights[ch]);
            end
        end
    endtask

    // ============================================================
    // 6. Golden Model Calculation
    // ============================================================
    task calculate_golden;
        reg [7:0] padded_img [0:IMG_H + 2*PADDING - 1][0:IMG_W + 2*PADDING - 1];
        integer y, x, ky, kx;
        reg signed [31:0] sum;
        integer ch;
        integer f_gold;
        begin
            for (y = 0; y < IMG_H + 2*PADDING; y = y + 1) begin
                for (x = 0; x < IMG_W + 2*PADDING; x = x + 1) begin
                    padded_img[y][x] = 0;
                end
            end

            for (y = 0; y < IMG_H; y = y + 1) begin
                for (x = 0; x < IMG_W; x = x + 1) begin
                    padded_img[y+PADDING][x+PADDING] = input_img[y*IMG_W + x];
                end
            end

            $display("[TB] Calculating Golden Model...");
            f_gold = $fopen("trace_tb_l1.txt", "w");

            for (y = 0; y < IMG_H; y = y + 1) begin
                for (x = 0; x < IMG_W; x = x + 1) begin
                     for (ch = 0; ch < CH_OUT; ch = ch + 1) begin
                        sum = 0;

                        // 3x3 Convolution
                        for (ky = 0; ky < 3; ky = ky + 1) begin
                            for (kx = 0; kx < 3; kx = kx + 1) begin
                                sum = sum + $signed({1'b0, padded_img[y+ky][x+kx]}) * $signed(test_weights[ch]);
                            end
                        end

                        if (sum < 0) sum = 0;       // ReLU
                        else sum = sum >>> QUANT_SHIFT; // Shift

                        if (sum > 127) sum = 127;   // Saturation
                        else if (sum < -128) sum = -128;

                        golden_out[ch][y*IMG_W + x] = sum[7:0];
                        $fwrite(f_gold, "%0d ", sum[7:0]);
                    end
                    $fwrite(f_gold, "\n");
                end
            end
            $fclose(f_gold);
        end
    endtask

    // ============================================================
    // 7. Main Simulation Flow
    // ============================================================
    initial begin
        file_handle = $fopen(W_FILE_DUMMY, "w");
        $fdisplay(file_handle, "00");
        $fclose(file_handle);

        $dumpfile("conv2d_layer1.vcd");
        $dumpvars(0, conv2d_layer1_tb);

        for (i = 0; i < IMG_H*IMG_W; i = i + 1) begin
            input_img[i] = (i % 255) + 1;
        end

        test_weights[0] = WEIGHT_CH0;
        test_weights[1] = WEIGHT_CH1;
        test_weights[2] = WEIGHT_CH2;
        test_weights[3] = WEIGHT_CH3;
        test_weights[4] = WEIGHT_CH4;
        test_weights[5] = WEIGHT_CH5;
        test_weights[6] = WEIGHT_CH6;
        test_weights[7] = WEIGHT_CH7;

        calculate_golden();

        rst_n    = 1;
        in_valid = 0;
        in_data  = 0;
        out_cnt  = 0;
        err_cnt  = 0;
        check_r  = 0;
        check_c  = 0;

        #10 rst_n = 0;
        #20 rst_n = 1;
        #20;

        set_weights();
        #10;

        $display("[TB] Start Streaming Data...");
        in_valid = 1;
        @(posedge clk);
        for (r = 0; r < IMG_H; r = r + 1) begin
            for (c = 0; c < IMG_W; c = c + 1) begin
                in_data = input_img[r*IMG_W + c];
                @(posedge clk);
            end
        end

        $display("[TB] Flushing Pipeline (Sending Dummy Rows)...");

        in_data  = 0;

        repeat(IMG_W * 2) @(posedge clk);

        in_valid = 0;

        repeat(100) @(posedge clk);

        if (err_cnt == 0) begin
            $display("\n==================================================");
            $display("  ALL PASS! (Total %0d pixels checked)", out_cnt);
            $display("==================================================\n");
        end else begin
            $display("\n==================================================");
            $display("  FAIL! Found %0d errors.", err_cnt);
            $display("  (Tip: If Act values are smaller/shifted, check pipeline latency)");
            $display("==================================================\n");
        end

        $finish;
    end

    // ============================================================
    // 8. Output Monitor
    // ============================================================
    always @(posedge clk) begin
        if (out_valid) begin
            if (out_cnt < IMG_W * IMG_H) begin

                for (i = 0; i < CH_OUT; i = i + 1) begin
                    if (out_conv_array[i] !== golden_out[i][out_cnt]) begin
                        $display("[FAIL] time=%0tns Ch%0d @(r:%0d, c:%0d) | Exp=%d | Act=%d",
                                 $time, i, check_r, check_c, golden_out[i][out_cnt], out_conv_array[i]);
                        err_cnt = err_cnt + 1;
                    end
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

endmodule
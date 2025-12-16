`timescale 1ns/1ps

module main_tb;

    // ============================================================
    // 1. Parameters
    // ============================================================
    parameter IMG_FILE = "test_image.txt";

    parameter W_FILE_L1 = "conv1_relu.txt";
    parameter W_FILE_L2 = "conv2_selu.txt";
    parameter W_FILE_L3 = "conv3_gelu.txt";
    parameter W_FILE_FC = "fc_weights.txt";
    parameter B_FILE_FC = "fc_biases.txt";

    parameter IMG_W = 28;
    parameter IMG_H = 28;

    // ============================================================
    // 2. Signals
    // ============================================================
    reg          clk;
    reg          rst_n;
    reg          in_valid;
    reg  [7:0]   in_data;

    wire [3:0]   class_out;
    wire         class_valid;
    wire         fc_out_valid;
    wire signed [31:0] class_value;
    wire signed [31:0] final_score;

    reg [7:0] img_mem [0:IMG_W*IMG_H-1];
    integer i, r, c;

    // ============================================================
    // 3. DUT
    // ============================================================
    main u_top (
        .clk         (clk),
        .rst_n       (rst_n),
        .in_valid    (in_valid),
        .in_data     (in_data),
        .class_out   (class_out),
        .class_valid (class_valid),
        .class_value (class_value),
        .final_score (final_score),
        .fc_out_valid(fc_out_valid)
    );

    // ============================================================
    // 4. Clock
    // ============================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // 5. Trace Dumping
    // ============================================================
    integer f_l1, f_l2, f_mp, f_l3, f_gap, f_fc;
    reg files_opened;

    initial begin
        // Initialize file descriptors to 0 (invalid)
        f_l1 = 0;
        f_l2 = 0;
        f_mp = 0;
        f_l3 = 0;
        f_gap = 0;
        f_fc = 0;
        files_opened = 0;

        // Wait a bit to ensure filesystem is ready
        #10;

        // Open files
        f_l1 = $fopen("trace_hw_l1.txt", "w");
        f_l2 = $fopen("trace_hw_l2.txt", "w");
        f_mp = $fopen("trace_hw_mp.txt", "w");
        f_l3 = $fopen("trace_hw_l3.txt", "w");
        f_gap = $fopen("trace_hw_gap.txt", "w");
        f_fc = $fopen("trace_hw_fc.txt", "w");

        // Check if files opened successfully
        if (f_l1 == 0) $display("[ERROR] Failed to open trace_hw_l1.txt");
        if (f_l2 == 0) $display("[ERROR] Failed to open trace_hw_l2.txt");
        if (f_mp == 0) $display("[ERROR] Failed to open trace_hw_mp.txt");
        if (f_l3 == 0) $display("[ERROR] Failed to open trace_hw_l3.txt");
        if (f_gap == 0) $display("[ERROR] Failed to open trace_hw_gap.txt");
        if (f_fc == 0) $display("[ERROR] Failed to open trace_hw_fc.txt");

        // Mark files as opened
        if (f_l1 != 0 && f_l2 != 0 && f_mp != 0 && f_l3 != 0 && f_gap != 0 && f_fc != 0) begin
            files_opened = 1;
        end
    end

    // Trace L1 (8 channels)
    always @(posedge clk) begin
        if (u_top.l1_valid && files_opened && f_l1 != 0) begin
            $fwrite(f_l1, "%d %d %d %d %d %d %d %d\n",
                u_top.l1_out0, u_top.l1_out1, u_top.l1_out2, u_top.l1_out3,
                u_top.l1_out4, u_top.l1_out5, u_top.l1_out6, u_top.l1_out7);
        end
    end

    // Trace L2 (16 channels)
    always @(posedge clk) begin
        if (u_top.l2_valid && files_opened && f_l2 != 0) begin
            $fwrite(f_l2, "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
                u_top.l2_out0, u_top.l2_out1, u_top.l2_out2, u_top.l2_out3,
                u_top.l2_out4, u_top.l2_out5, u_top.l2_out6, u_top.l2_out7,
                u_top.l2_out8, u_top.l2_out9, u_top.l2_out10, u_top.l2_out11,
                u_top.l2_out12, u_top.l2_out13, u_top.l2_out14, u_top.l2_out15);
        end
    end

    // Trace MP (16 channels) - Now trace FIFO output
    always @(posedge clk) begin
        if (u_top.fifo_rd_valid && files_opened && f_mp != 0) begin
            $fwrite(f_mp, "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
                u_top.fifo_rd_data0, u_top.fifo_rd_data1, u_top.fifo_rd_data2, u_top.fifo_rd_data3,
                u_top.fifo_rd_data4, u_top.fifo_rd_data5, u_top.fifo_rd_data6, u_top.fifo_rd_data7,
                u_top.fifo_rd_data8, u_top.fifo_rd_data9, u_top.fifo_rd_data10, u_top.fifo_rd_data11,
                u_top.fifo_rd_data12, u_top.fifo_rd_data13, u_top.fifo_rd_data14, u_top.fifo_rd_data15);
        end
    end

    // Trace L3 (32 channels)
    reg l4_valid_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l4_valid_d <= 0;
        end else begin
            l4_valid_d <= u_top.l4_valid;
        end
    end
    wire l4_valid_pulse = u_top.l4_valid && !l4_valid_d;

    always @(posedge clk) begin
        if (l4_valid_pulse && files_opened && f_l3 != 0) begin
            if ($time < 100000) begin
                $display("[TB_TRACE_L3] Writing trace: l4_valid=%d, l4_valid_d=%d, l4_valid_pulse=%d, out[0]=%d, out[31]=%d",
                         u_top.l4_valid, l4_valid_d, l4_valid_pulse, u_top.l4_out_w[0], u_top.l4_out_w[31]);
            end
            $fwrite(f_l3, "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
                u_top.l4_out_w[0], u_top.l4_out_w[1], u_top.l4_out_w[2], u_top.l4_out_w[3],
                u_top.l4_out_w[4], u_top.l4_out_w[5], u_top.l4_out_w[6], u_top.l4_out_w[7],
                u_top.l4_out_w[8], u_top.l4_out_w[9], u_top.l4_out_w[10], u_top.l4_out_w[11],
                u_top.l4_out_w[12], u_top.l4_out_w[13], u_top.l4_out_w[14], u_top.l4_out_w[15],
                u_top.l4_out_w[16], u_top.l4_out_w[17], u_top.l4_out_w[18], u_top.l4_out_w[19],
                u_top.l4_out_w[20], u_top.l4_out_w[21], u_top.l4_out_w[22], u_top.l4_out_w[23],
                u_top.l4_out_w[24], u_top.l4_out_w[25], u_top.l4_out_w[26], u_top.l4_out_w[27],
                u_top.l4_out_w[28], u_top.l4_out_w[29], u_top.l4_out_w[30], u_top.l4_out_w[31]);
        end
    end

    always @(posedge clk) begin
        if (u_top.gap_valid_global && files_opened && f_gap != 0) begin
             $fwrite(f_gap, "%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n",
                u_top.gap_out_pack[0], u_top.gap_out_pack[1], u_top.gap_out_pack[2], u_top.gap_out_pack[3],
                u_top.gap_out_pack[4], u_top.gap_out_pack[5], u_top.gap_out_pack[6], u_top.gap_out_pack[7],
                u_top.gap_out_pack[8], u_top.gap_out_pack[9], u_top.gap_out_pack[10], u_top.gap_out_pack[11],
                u_top.gap_out_pack[12], u_top.gap_out_pack[13], u_top.gap_out_pack[14], u_top.gap_out_pack[15],
                u_top.gap_out_pack[16], u_top.gap_out_pack[17], u_top.gap_out_pack[18], u_top.gap_out_pack[19],
                u_top.gap_out_pack[20], u_top.gap_out_pack[21], u_top.gap_out_pack[22], u_top.gap_out_pack[23],
                u_top.gap_out_pack[24], u_top.gap_out_pack[25], u_top.gap_out_pack[26], u_top.gap_out_pack[27],
                u_top.gap_out_pack[28], u_top.gap_out_pack[29], u_top.gap_out_pack[30], u_top.gap_out_pack[31]);
        end
    end

    always @(posedge clk) begin
        if (fc_out_valid && files_opened && f_fc != 0) begin
            $fwrite(f_fc, "%d\n", final_score);
        end
    end

    // ============================================================
    // 6. Main Test Flow
    // ============================================================
    initial begin
        $display("==================================================");
        $display("  Start Trace Generation Testbench");
        $display("==================================================");

        $readmemh(IMG_FILE, img_mem);
        $display("[TB] Loaded image from %s", IMG_FILE);

        // Load Weights
        $readmemh(W_FILE_L1, u_top.u_layer1.weight_data);
        $readmemh(W_FILE_L2, u_top.u_layer2.weight_data);
        $readmemh(W_FILE_L3, u_top.u_layer4.weight_data);
        $readmemh(W_FILE_FC, u_top.u_fc.weights);
        $readmemh(B_FILE_FC, u_top.u_fc.biases);

        rst_n    = 1;
        in_valid = 0;
        in_data  = 0;

        #20 rst_n = 0;
        #20 rst_n = 1;
        #100;

        fork
            begin
                $display("[TB] Sending Image Data...");
                for (r = 0; r < IMG_H; r = r + 1) begin
                    for (c = 0; c < IMG_W; c = c + 1) begin
                        in_valid = 1;
                        in_data = img_mem[r * IMG_W + c];
                        @(posedge clk);

                        in_valid = 0;
                        repeat(50) @(posedge clk);
                    end
                end

                $display("[TB] Flushing...");
                in_valid = 0;
                in_data = 0;
                for (i = 0; i < 100; i = i + 1) begin
                     in_valid = 1;
                     in_data = 0;
                     @(posedge clk);
                end
                in_valid = 0;
                repeat(100) @(posedge clk);

                $display("[TB] Stimulus (Send Data) Finished.");
            end

            begin
                wait(class_valid);
                $display("\n==================================================");
                $display("  INFERENCE COMPLETE");
                $display("==================================================");
                $display("  Predicted Class: %0d", class_out);
                $display("  Class Value:     %0d", class_value);
                $display("==================================================\n");
                $display("[TB] Captured class_valid!");
                #5000;
                $display("[TB] Monitor (Wait for Result) Finished Successfully.");
            end
        join

        $fclose(f_l1);
        $fclose(f_l2);
        $fclose(f_mp);
        $fclose(f_l3);
        $fclose(f_gap);
        $fclose(f_fc);
        #100;
        $finish;
    end

    // Timeout
    initial begin
        #5000000;
        $display("[TB] Timeout!");
        $display("[TB] Current time: %0t", $time);
        $finish;
    end

endmodule

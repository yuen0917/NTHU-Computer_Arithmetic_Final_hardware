`timescale 1ns/1ps

module main_batch_tb;

    // ============================================================
    // 1. Parameters
    // ============================================================
    parameter TOTAL_IMAGES = 100;

    // Files
    parameter IMG_FILE_ALL = "all_test_images.txt";
    parameter LBL_FILE_ALL = "all_labels.txt";

    // Weights
    parameter W_FILE_L1    = "conv1_relu.txt";
    parameter W_FILE_L2    = "conv2_selu.txt";
    parameter W_FILE_L3    = "conv3_gelu.txt";
    parameter W_FILE_FC    = "fc_weights.txt";
    parameter B_FILE_FC    = "fc_biases.txt";

    parameter IMG_W        = 28;
    parameter IMG_H        = 28;
    parameter IMG_SIZE     = 784;

    // ============================================================
    // 2. Signals
    // ============================================================
    reg                clk;
    reg                rst_n;
    reg                in_valid;
    reg         [ 7:0] in_data;

    wire        [ 3:0] class_out;
    wire               class_valid;
    wire signed [31:0] class_value;
    wire signed [31:0] final_score;
    wire               fc_out_valid;

    // Memory
    reg [7:0] all_images_mem [0 : TOTAL_IMAGES * IMG_SIZE - 1];
    reg [3:0] all_labels_mem [0 : TOTAL_IMAGES - 1];

    integer i, img_idx;
    integer correct_cnt;
    integer pixel_offset;

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
    // 5. Main Test Flow
    // ============================================================
    initial begin
        $display("=========================================================");
        $display("  Start Batch Simulation (Total: %0d images)", TOTAL_IMAGES);
        $display("=========================================================");

        // Load Weights
        $readmemh(W_FILE_L1, u_top.u_layer1.weight_data);
        $readmemh(W_FILE_L2, u_top.u_layer2.weight_data);
        $readmemh(W_FILE_L3, u_top.u_layer4.weight_data);
        $readmemh(W_FILE_FC, u_top.u_fc.weights);
        $readmemh(B_FILE_FC, u_top.u_fc.biases);

        // Load Data
        $readmemh(IMG_FILE_ALL, all_images_mem);
        $readmemh(LBL_FILE_ALL, all_labels_mem);
        $display("[TB] Loaded images and labels.");

        rst_n       = 1;
        in_valid    = 0;
        in_data     = 0;
        correct_cnt = 0;

        // --- Batch Loop ---
        for (img_idx = 0; img_idx < TOTAL_IMAGES; img_idx = img_idx + 1) begin

            // 1. Reset
            #50 rst_n = 0;
            #50 rst_n = 1;
            #100;

            pixel_offset = img_idx * IMG_SIZE;

            fork : batch_fork
                // Thread 1: Send data + Flush
                begin
                    in_valid = 1;
                    for (i = 0; i < IMG_SIZE; i = i + 1) begin
                        in_data = all_images_mem[pixel_offset + i];
                        @(posedge clk);
                    end

                    // Flush
                    in_data = 0;
                    repeat (15 * 28) @(posedge clk);
                    in_valid = 0;
                end

                // Thread 2: Wait for result and check
                begin
                    wait(class_valid);

                    if (class_out == all_labels_mem[img_idx]) begin
                        correct_cnt = correct_cnt + 1;
                    end else begin
                        $display("    Image %0d: FAIL (Pred: %d, True: %d)",
                                 img_idx, class_out, all_labels_mem[img_idx]);
                    end
                    disable batch_fork;
                end

                // Thread 3: Timeout protection
                begin
                    repeat (5000) @(posedge clk);
                    $display("    Image %0d: TIMEOUT", img_idx);
                    disable batch_fork;
                end
            join

            in_valid = 0;
            in_data = 0;

            // Small delay
            #100;
        end

        // --- Report ---
        $display("=========================================================");
        $display("  BATCH TEST COMPLETE");
        $display("=========================================================");
        $display("  Total Images: %0d", TOTAL_IMAGES);
        $display("  Correct:      %0d", correct_cnt);
        $display("  Accuracy:     %0d.%0d%%", (correct_cnt * 100) / TOTAL_IMAGES, ((correct_cnt * 1000) / TOTAL_IMAGES) % 10);
        $display("=========================================================");

        $finish;
    end

endmodule
`timescale 1ns/1ps
// ============================================================
// Max Pooling Unit Testbench
// ============================================================
module max_pool_unit_tb;

    // ============================================================
    // 1. Parameters and Constants (28x28 -> 14x14)
    // ============================================================
    parameter IMG_W = 28;
    parameter IMG_H = 28;

    // The width and height after output are half of the original image
    parameter OUT_W = IMG_W / 2;
    parameter OUT_H = IMG_H / 2;

    localparam TOTAL_PIXELS_IN  = IMG_W * IMG_H;       // Total pixels in the input image
    localparam TOTAL_PIXELS_OUT = OUT_W * OUT_H;       // Total pixels in the output image

    // ============================================================
    // 2. Signals Declaration
    // ============================================================
    reg          clk;
    reg          rst_n;
    reg          in_valid;
    reg  [7:0]   in_data;

    wire         out_valid;
    wire [7:0]   out_data;

    // Test data storage area
    reg  [7:0]   input_img   [0:TOTAL_PIXELS_IN-1];
    reg  [7:0]   expected_img[0:TOTAL_PIXELS_OUT-1]; // Golden Model results

    // Loop and counter variables
    integer i;
    integer r, c; // row, col for golden model loop
    integer out_cnt;
    integer err_cnt;
    integer test_case;

    // ============================================================
    // 3. DUT Instance
    // ============================================================
    max_pool_unit #(
        .IMG_W (IMG_W),
        .IMG_H (IMG_H)
    ) u_dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_data  (in_data),
        .in_valid (in_valid),
        .out_data (out_data),
        .out_valid(out_valid)
    );

    // ============================================================
    // 4. Clock Generation (100MHz)
    // ============================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // 5. Golden Model Calculation Task
    //    Simulate the software behavior of 2x2 Max Pooling
    // ============================================================
    task calculate_golden;
        reg signed [7:0] p0, p1, p2, p3;
        reg signed [7:0] max1, max2, final_max;
        integer idx_in_base;
        integer idx_out;
        begin
            $display("[Golden Model] Calculating expected results...");

            // Traverse each pixel position in the output (14x14)
            for (r = 0; r < OUT_H; r = r + 1) begin
                for (c = 0; c < OUT_W; c = c + 1) begin

                    // Find the top-left corner coordinates of the 2x2 block in the input image (2r, 2c)
                    // Convert to 1D array index
                    idx_in_base = (r * 2) * IMG_W + (c * 2);

                    // Get the four pixels of the 2x2 block
                    p0 = input_img[idx_in_base];             // Top-Left
                    p1 = input_img[idx_in_base + 1];         // Top-Right
                    p2 = input_img[idx_in_base + IMG_W];     // Bottom-Left
                    p3 = input_img[idx_in_base + IMG_W + 1]; // Bottom-Right

                    // Find the maximum value
                    max1 = ($signed(p0) > $signed(p1)) ? p0 : p1;
                    max2 = ($signed(p2) > $signed(p3)) ? p2 : p3;
                    final_max = ($signed(max1) > $signed(max2)) ? max1 : max2;

                    // Store the expected result array
                    idx_out = r * OUT_W + c;
                    expected_img[idx_out] = final_max;
                end
            end
        end
    endtask

    // ============================================================
    // 6. Main Test Flow
    // ============================================================
    initial begin
        // Waveform file setting
        $dumpfile("max_pool_wave.vcd");
        $dumpvars(0, max_pool_unit_tb);

        $display("--------------------------------------------------");
        $display(" Start Simulation - Max Pooling (2x2) ");
        $display("--------------------------------------------------");

        rst_n    = 1;
        in_valid = 0;
        in_data  = 0;
        err_cnt  = 0;

        // ========================================================
        // Test Case 1: Reset Test
        // ========================================================
        $display("\n=== Test Case 1: Reset Test ===");
        #10 rst_n = 0;
        #20 rst_n = 1;
        #10;

        // ========================================================
        // Test Case 2: Incremental Values
        // Incremental values 0, 1, 2... increasing, to observe if the maximum value is selected
        // ========================================================
        test_case = 2;
        $display("\n=== Test Case 2: Incremental Values (0..%0d) ===", TOTAL_PIXELS_IN-1);

        // 1. Prepare data
        for (i = 0; i < TOTAL_PIXELS_IN; i = i + 1) begin
            input_img[i] = i % 256; // Ensure within 8-bit range
        end

        // 2. Calculate Golden
        calculate_golden();

        // 3. Reset DUT
        #10 rst_n = 0; #20 rst_n = 1; #10;

        // 4. Send data and compare实时
        in_valid = 1;
        out_cnt  = 0; // Used to track the current comparison to the number of outputs

        $display("[TB Info] Streaming data and checking output...");

        for (i = 0; i < TOTAL_PIXELS_IN; i = i + 1) begin
            in_data = input_img[i];

            @(posedge clk);

            // Add Hold Time to prevent Race Condition
            #1;

            // Check output
            // Because MaxPool is streaming output, out_valid will be pulled high at specific time points
            if (out_valid) begin
                if (out_cnt >= TOTAL_PIXELS_OUT) begin
                    $display("[ERROR] Received more outputs than expected!");
                    err_cnt = err_cnt + 1;
                end else if (out_data !== expected_img[out_cnt]) begin
                    $display("[FAIL] Output #%0d | Exp=%3d | Act=%3d",
                             out_cnt, expected_img[out_cnt], out_data);
                    err_cnt = err_cnt + 1;
                end
                // To avoid flooding the screen, only print the first few successful ones, or print if there is an error
                // else begin
                //    $display("[PASS] Output #%0d | Exp=%3d | Act=%3d", out_cnt, expected_img[out_cnt], out_data);
                // end
                out_cnt = out_cnt + 1;
            end
        end
        in_valid = 0; // End input

        // Ensure the correct number of outputs are received
        if (out_cnt !== TOTAL_PIXELS_OUT) begin
            $display("[ERROR] Test Case %0d | Expected %0d outputs, received %0d",
                     test_case, TOTAL_PIXELS_OUT, out_cnt);
            err_cnt = err_cnt + 1;
        end else begin
            $display("[INFO] Test Case %0d Finished. Received all %0d outputs.", test_case, out_cnt);
        end

        #50;

        // ========================================================
        // Test Case 3: Random Values
        // ========================================================
        test_case = 3;
        $display("\n=== Test Case 3: Random Values ===");

        // 1. Prepare random data
        for (i = 0; i < TOTAL_PIXELS_IN; i = i + 1) begin
            input_img[i] = $random % 256;
        end

        // 2. Calculate Golden
        calculate_golden();

        // 3. Reset
        #10 rst_n = 0; #20 rst_n = 1; #10;

        // 4. Execute
        in_valid = 1;
        out_cnt  = 0;

        for (i = 0; i < TOTAL_PIXELS_IN; i = i + 1) begin
            in_data = input_img[i];
            @(posedge clk);
            #1; // Hold time fix

            if (out_valid) begin
                if (out_cnt < TOTAL_PIXELS_OUT) begin
                    if (out_data !== expected_img[out_cnt]) begin
                        $display("[FAIL] Output #%0d | Exp=%3d | Act=%3d",
                                 out_cnt, expected_img[out_cnt], out_data);
                        err_cnt = err_cnt + 1;
                    end
                end
                out_cnt = out_cnt + 1;
            end
        end
        in_valid = 0;

        if (out_cnt !== TOTAL_PIXELS_OUT) begin
            $display("[ERROR] Test Case %0d | Expected %0d outputs, received %0d",
                     test_case, TOTAL_PIXELS_OUT, out_cnt);
            err_cnt = err_cnt + 1;
        end else begin
            $display("[INFO] Test Case %0d Finished. Received all %0d outputs.", test_case, out_cnt);
        end
        #50;

        // ============================================================
        // Summary
        // ============================================================
        if (err_cnt == 0) begin
            $display("\n==================================================");
            $display("  ALL PASS! Max Pooling verified successfully.");
            $display("==================================================\n");
        end else begin
            $display("\n==================================================");
            $display("  FAIL! Found %0d errors.", err_cnt);
            $display("==================================================\n");
        end

        $finish;
    end

endmodule
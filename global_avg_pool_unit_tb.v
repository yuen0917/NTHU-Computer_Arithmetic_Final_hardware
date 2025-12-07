`timescale 1ns/1ps
// ============================================================
// Global Average Pooling Unit Testbench
// ============================================================
module global_avg_pool_unit_tb;

    // ============================================================
    // 1. Parameters and Constants
    // ============================================================
    parameter IMG_W = 14;
    parameter IMG_H = 14;
    localparam TOTAL_PIXELS = IMG_W * IMG_H;

    // ============================================================
    // 2. Signals Declaration
    // ============================================================
    reg          clk;
    reg          rst_n;
    reg          in_valid;
    reg  [7:0]   in_data;

    wire         out_valid;
    wire [7:0]   out_data;

    reg  [7:0]   input_img [0:TOTAL_PIXELS-1];
    reg  [7:0]   golden_out;

    integer i;
    integer out_cnt;
    integer err_cnt;
    integer test_case;
    integer output_received;

    // ============================================================
    // 3. DUT Instance
    // ============================================================
    global_avg_pool_unit #(
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
    // 4. Clock Generation
    // ============================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // 5. Golden Model Calculation
    // ============================================================
    task calculate_golden;
        integer sum;
        integer result;
        begin
            sum = 0;
            for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
                sum = sum + input_img[i];
            end
            result = (sum * 167) >> 15;
            if (result > 255) result = 255;
            else if (result < 0) result = 0;

            golden_out = result[7:0];
            $display("[Golden Model] Sum = %0d, Average = %0d", sum, golden_out);
        end
    endtask

    // ============================================================
    // 6. Main Test Flow
    // ============================================================
    initial begin
        $dumpfile("global_avg_pool_wave.vcd");
        $dumpvars(0, global_avg_pool_unit_tb);

        $display("--------------------------------------------------");
        $display(" Start Simulation ");
        $display("--------------------------------------------------");

        rst_n    = 1;
        in_valid = 0;
        in_data  = 0;
        out_cnt  = 0;
        err_cnt  = 0;

        // ========================================================
        // Test Case 1: Reset
        // ========================================================
        #10 rst_n = 0;
        #20 rst_n = 1;
        #10;

        // ========================================================
        // Test Case 2: All 100
        // ========================================================
        test_case = 2;
        $display("\n=== Test Case 2: All Pixels = 100 ===");
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) input_img[i] = 100;
        calculate_golden();

        #10 rst_n = 0; #20 rst_n = 1; #10; // Reset

        in_valid = 1;
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            in_data = input_img[i];
            @(posedge clk);
            #1; // <--- Add this, keep the data stable for 1ns, prevent hardware from catching it wrong
        end
        #1; in_valid = 0; // Hold time fix

        // Check Output
        output_received = 0;
        for (i = 0; i < 5; i = i + 1) begin
            if (out_valid) begin
                // [Debug] Print the internal current_sum
                $display("[DEBUG HW] RTL Current Sum = %0d (Expected Sum: 19600)", u_dut.current_sum);

                if (out_data !== golden_out) begin
                    $display("[FAIL] TC%0d | Exp=%0d | Act=%0d", test_case, golden_out, out_data);
                    err_cnt = err_cnt + 1;
                end else begin
                    $display("[PASS] TC%0d | Exp=%0d | Act=%0d", test_case, golden_out, out_data);
                end
                output_received = 1;
                out_cnt = out_cnt + 1;
                i = 5; // break
            end
            @(posedge clk);
        end
        if (!output_received) begin
          $display("[ERROR] TC%0d No Output", test_case);
          err_cnt = err_cnt + 1;
        end
        #50;

        // ========================================================
        // Test Case 3: Incremental 1..196
        // ========================================================
        test_case = 3;
        $display("\n=== Test Case 3: Incremental (1..196) ===");
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) input_img[i] = i + 1;
        calculate_golden();

        #10 rst_n = 0; #20 rst_n = 1; #10; // Reset

        in_valid = 1;
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            in_data = input_img[i];
            @(posedge clk);
            #1; // <--- Add this, keep the data stable for 1ns, prevent hardware from catching it wrong
        end
        #1; in_valid = 0;

        // Check Output
        output_received = 0;
        for (i = 0; i < 5; i = i + 1) begin
            if (out_valid) begin
                // [Debug] Print the internal current_sum, this will tell us how much the hardware has added
                $display("[DEBUG HW] RTL Current Sum = %0d (Expected Sum: 19306)", u_dut.current_sum);

                if (out_data !== golden_out) begin
                    $display("[FAIL] TC%0d | Exp=%0d | Act=%0d", test_case, golden_out, out_data);
                    err_cnt = err_cnt + 1;
                end else begin
                    $display("[PASS] TC%0d | Exp=%0d | Act=%0d", test_case, golden_out, out_data);
                end
                output_received = 1;
                out_cnt = out_cnt + 1;
                i = 5;
            end
            @(posedge clk);
        end
        if (!output_received) begin
          $display("[ERROR] TC%0d No Output", test_case);
          err_cnt = err_cnt + 1;
        end
        #50;

        // ========================================================
        // Test Case 4: Max Value
        // ========================================================
        test_case = 4;
        $display("\n=== Test Case 4: Max Values (255) ===");
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) input_img[i] = 255;
        calculate_golden();

        #10 rst_n = 0; #20 rst_n = 1; #10;

        in_valid = 1;
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            in_data = input_img[i];
            @(posedge clk);
            #1; // <--- Add this, keep the data stable for 1ns, prevent hardware from catching it wrong
        end
        #1; in_valid = 0;

        output_received = 0;
        for (i = 0; i < 5; i = i + 1) begin
            if (out_valid) begin
                 $display("[DEBUG HW] RTL Current Sum = %0d (Expected Sum: 49980)", u_dut.current_sum);
                if (out_data !== golden_out) begin
                    $display("[FAIL] TC%0d | Exp=%0d | Act=%0d", test_case, golden_out, out_data);
                    err_cnt = err_cnt + 1;
                end else begin
                    $display("[PASS] TC%0d | Exp=%0d | Act=%0d", test_case, golden_out, out_data);
                end
                output_received = 1;
                out_cnt = out_cnt + 1;
                i = 5;
            end
            @(posedge clk);
        end
        if (!output_received) begin
          $display("[ERROR] TC%0d No Output", test_case);
          err_cnt = err_cnt + 1;
        end
        #50;
        // ========================================================
        // Test Case 5: Random Values
        // ========================================================
        test_case = 5;
        $display("\n=== Test Case 5: Random Values ===");
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) input_img[i] = ((i * 17 + 23) % 256);
        calculate_golden();

        #10 rst_n = 0; #20 rst_n = 1; #10;

        in_valid = 1;
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            in_data = input_img[i];
            @(posedge clk);
            #1; // <--- Add this, keep the data stable for 1ns, prevent hardware from catching it wrong
        end
        in_valid = 0;

        output_received = 0;
        for (i = 0; i < 5; i = i + 1) begin
            if (out_valid) begin
                if (out_data !== golden_out) begin
                    $display("[FAIL] TC%0d | Exp=%0d | Act=%0d", test_case, golden_out, out_data);
                    err_cnt = err_cnt + 1;
                end else begin
                    $display("[PASS] TC%0d | Exp=%0d | Act=%0d", test_case, golden_out, out_data);
                end
                output_received = 1;
                out_cnt = out_cnt + 1;
                i = 5;
            end
            @(posedge clk);
        end
        if (!output_received) begin
          $display("[ERROR] TC%0d No Output", test_case);
          err_cnt = err_cnt + 1;
        end
        #50;

        // ========================================================
        // Summary
        // ========================================================
        if (err_cnt == 0)
            $display("\n=== ALL PASS! ===");
        else
            $display("\n=== FAIL! Found %0d errors ===", err_cnt);

        $finish;
    end
    // ============================================================
    // 8. Strong Debug Block: Print the accumulative process per cycle
    //    This will help us find out why TC3 is calculating 120 more
    // ============================================================
    // always @(posedge clk) begin
    //   // Only print when TC3 and in_valid is high
    //   if (test_case == 3 && in_valid) begin
    //       $display("Time %0t | Pixel_Cnt=%0d | In_Data=%0d | Sum_Acc(Before)=%0d | Current_Sum=%0d",
    //                $time, u_dut.pixel_cnt, in_data, u_dut.sum_acc, u_dut.current_sum);
    //   end
    // end
endmodule
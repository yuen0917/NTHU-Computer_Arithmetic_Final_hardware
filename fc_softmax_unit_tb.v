`timescale 1ns/1ps
// ============================================================
// FC & Softmax Unit Testbench
// ============================================================
module fc_softmax_unit_tb;

    // ============================================================
    // 1. Parameters and Constants
    // ============================================================
    parameter IN_DIM  = 32;
    parameter OUT_DIM = 10;

    // Weight and bias file names
    parameter W_FILE = "fc_weights.txt";
    parameter B_FILE = "fc_biases.txt";

    // ============================================================
    // 2. Signals Declaration
    // ============================================================
    reg          clk;
    reg          rst_n;
    reg  [7:0]   in_data;
    reg          in_valid;

    wire signed [31:0] out_data;
    wire               out_valid;
    wire        [3:0]  class_out;
    wire               class_valid;

    reg signed [7:0]  tb_weights [0:IN_DIM * OUT_DIM - 1];
    reg signed [31:0] tb_biases  [0:OUT_DIM - 1];
    reg        [7:0]  input_vec  [0:IN_DIM - 1];

    reg signed [31:0] exp_scores [0:OUT_DIM - 1];
    reg        [3:0]  exp_class;
    reg signed [31:0] exp_max_val;

    integer i, j;
    integer out_cnt;
    integer err_cnt;
    integer test_case;
    integer file_handle;

    // ============================================================
    // 3. File generation and loading task
    // ============================================================
    initial begin
      file_handle = $fopen(W_FILE, "w");
      for (i = 0; i < IN_DIM * OUT_DIM; i = i + 1) begin
          tb_weights[i] = $random % 256;
          $fdisplay(file_handle, "%h", tb_weights[i]);
      end
      $fclose(file_handle);

      file_handle = $fopen(B_FILE, "w");
      for (i = 0; i < OUT_DIM; i = i + 1) begin
          tb_biases[i] = $random;
          $fdisplay(file_handle, "%h", tb_biases[i]);
      end
      $fclose(file_handle);

      $display("[TB Info] Generated random %s and %s", W_FILE, B_FILE);

      $readmemh(W_FILE, u_dut.weights);
      $readmemh(B_FILE, u_dut.biases);
    end
    // ============================================================
    // 4. DUT Instance
    // ============================================================
    fc_softmax_unit #(
        .IN_DIM (IN_DIM),
        .OUT_DIM(OUT_DIM)
    ) u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .in_data    (in_data),
        .in_valid   (in_valid),
        .out_data   (out_data),
        .out_valid  (out_valid),
        .class_out  (class_out),
        .class_valid(class_valid)
    );

    // ============================================================
    // 5. Clock Generation
    // ============================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // 6. Golden Model Calculation Task
    // ============================================================
    task calculate_golden;
        integer k, n;
        reg signed [31:0] acc;
        begin
            exp_max_val = -2147483648; // Initialize minimum value
            exp_class = 0;

            for (n = 0; n < OUT_DIM; n = n + 1) begin
                acc = tb_biases[n];

                for (k = 0; k < IN_DIM; k = k + 1) begin
                    acc = acc + ($signed({1'b0, input_vec[k]}) * tb_weights[n * IN_DIM + k]);
                end

                exp_scores[n] = acc;

                if (n == 0) begin
                    exp_max_val = acc;
                    exp_class = 0;
                end else begin
                    if (acc > exp_max_val) begin
                        exp_max_val = acc;
                        exp_class = n;
                    end
                end
            end
        end
    endtask

    // ============================================================
    // 7. Main Test Flow
    // ============================================================
    initial begin
        $dumpfile("fc_softmax_wave.vcd");
        $dumpvars(0, fc_softmax_unit_tb);

        $display("--------------------------------------------------");
        $display(" Start Simulation - FC & Softmax Unit ");
        $display("--------------------------------------------------");

        rst_n    = 1;
        in_valid = 0;
        in_data  = 0;
        err_cnt  = 0;

        #100;
        rst_n = 0;
        #20 rst_n = 1;
        #10;

        // ========================================================
        // Loop test multiple Cases
        // ========================================================
        for (test_case = 1; test_case <= 5; test_case = test_case + 1) begin
            $display("\n=== Test Case %0d ===", test_case);

            // 1. Prepare random input data
            for (i = 0; i < IN_DIM; i = i + 1) begin
                input_vec[i] = $random % 256;
            end

            // 2. Calculate expected results (Golden)
            calculate_golden();

            // 3. Send data to DUT
            in_valid = 1;
            for (i = 0; i < IN_DIM; i = i + 1) begin
                in_data = input_vec[i];
                @(posedge clk);
                #1; // Hold time
            end
            in_valid = 0;
            in_data  = 0;

            // 4. Check output
            out_cnt = 0;

            fork : check_output
                begin
                    while (out_cnt < OUT_DIM) begin
                        @(posedge clk);
                        #1; // Sampling delay
                        if (out_valid) begin
                            if (out_data !== exp_scores[out_cnt]) begin
                                $display("[FAIL] Class %0d Score | Exp=%d | Act=%d",
                                         out_cnt, exp_scores[out_cnt], out_data);
                                err_cnt = err_cnt + 1;
                            end else begin
                                $display("[PASS] Class %0d Score | Val=%d", out_cnt, out_data);
                            end
                            out_cnt = out_cnt + 1;
                        end
                    end

                    while (!class_valid) @(posedge clk);
                    #1; // Sampling

                    if (class_out !== exp_class) begin
                        $display("[FAIL] Max Class Index | Exp=%d (MaxVal=%d) | Act=%d",
                                 exp_class, exp_max_val, class_out);
                        err_cnt = err_cnt + 1;
                    end else begin
                         $display("[PASS] Max Class Index | Class=%d (MaxVal=%d)", class_out, exp_max_val);
                    end

                    disable check_output;
                end

                begin
                    repeat(100) @(posedge clk);
                    $display("[ERROR] Test Case %0d Timeout!", test_case);
                    err_cnt = err_cnt + 1;
                    disable check_output;
                end
            join

            #20;
        end

        // ============================================================
        // Summary
        // ============================================================
        if (err_cnt == 0) begin
            $display("\n==================================================");
            $display("  ALL PASS! FC Softmax Unit verified.");
            $display("==================================================\n");
        end else begin
            $display("\n==================================================");
            $display("  FAIL! Found %0d errors.", err_cnt);
            $display("==================================================\n");
        end
        $finish;
    end

endmodule
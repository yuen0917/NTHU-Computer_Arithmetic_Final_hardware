`timescale 1ns/1ps

// ============================================================
// Testbench for Conv2d Layer 3 (L3)
// Purpose: Test L3 with batch reading strategy (28 pixels per batch)
// ============================================================
module conv2d_layer3_tb;

    // Parameters
    localparam PADDING = 1;
    localparam IMG_W = 14;
    localparam IMG_H = 14;
    localparam CH_IN = 16;
    localparam CH_OUT = 32;
    localparam QUANT_SHIFT = 7;
    localparam BATCH_SIZE = 28;  // 2 rows × 14 pixels = 28 pixels per batch
    localparam TOTAL_PIXELS = 196;  // 14×14 = 196 pixels

    // Clock and Reset
    reg clk;
    reg rst_n;

    // DUT Signals
    reg in_valid;
    reg [7:0] in_data0, in_data1, in_data2, in_data3;
    reg [7:0] in_data4, in_data5, in_data6, in_data7;
    reg [7:0] in_data8, in_data9, in_data10, in_data11;
    reg [7:0] in_data12, in_data13, in_data14, in_data15;
    reg fifo_empty;
    reg fifo_batch_ready;
    reg fifo_last_batch;

    wire out_valid;
    wire calc_busy_out;
    wire rd_en_out;
    wire signed [7:0] out_conv0,  out_conv1,  out_conv2,  out_conv3;
    wire signed [7:0] out_conv4,  out_conv5,  out_conv6,  out_conv7;
    wire signed [7:0] out_conv8,  out_conv9,  out_conv10, out_conv11;
    wire signed [7:0] out_conv12, out_conv13, out_conv14, out_conv15;
    wire signed [7:0] out_conv16, out_conv17, out_conv18, out_conv19;
    wire signed [7:0] out_conv20, out_conv21, out_conv22, out_conv23;
    wire signed [7:0] out_conv24, out_conv25, out_conv26, out_conv27;
    wire signed [7:0] out_conv28, out_conv29, out_conv30, out_conv31;

    // Instantiate DUT
    conv2d_layer3 #(
        .PADDING(PADDING), .IMG_W(IMG_W), .IMG_H(IMG_H),
        .CH_IN(CH_IN), .CH_OUT(CH_OUT), .QUANT_SHIFT(QUANT_SHIFT)
    ) u_dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .in_data0(in_data0),   .in_data1(in_data1),   .in_data2(in_data2),   .in_data3(in_data3),
        .in_data4(in_data4),   .in_data5(in_data5),   .in_data6(in_data6),   .in_data7(in_data7),
        .in_data8(in_data8),   .in_data9(in_data9),   .in_data10(in_data10), .in_data11(in_data11),
        .in_data12(in_data12), .in_data13(in_data13), .in_data14(in_data14), .in_data15(in_data15),
        .fifo_empty(fifo_empty),
        .fifo_batch_ready(fifo_batch_ready),
        .fifo_last_batch(fifo_last_batch),
        .out_valid(out_valid),
        .calc_busy_out(calc_busy_out),
        .rd_en_out(rd_en_out),
        .out_conv0(out_conv0),   .out_conv1(out_conv1),   .out_conv2(out_conv2),   .out_conv3(out_conv3),
        .out_conv4(out_conv4),   .out_conv5(out_conv5),   .out_conv6(out_conv6),   .out_conv7(out_conv7),
        .out_conv8(out_conv8),   .out_conv9(out_conv9),   .out_conv10(out_conv10), .out_conv11(out_conv11),
        .out_conv12(out_conv12), .out_conv13(out_conv13), .out_conv14(out_conv14), .out_conv15(out_conv15),
        .out_conv16(out_conv16), .out_conv17(out_conv17), .out_conv18(out_conv18), .out_conv19(out_conv19),
        .out_conv20(out_conv20), .out_conv21(out_conv21), .out_conv22(out_conv22), .out_conv23(out_conv23),
        .out_conv24(out_conv24), .out_conv25(out_conv25), .out_conv26(out_conv26), .out_conv27(out_conv27),
        .out_conv28(out_conv28), .out_conv29(out_conv29), .out_conv30(out_conv30), .out_conv31(out_conv31)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    integer pixel_cnt;
    integer batch_cnt;
    integer output_cnt;
    integer f_trace;

    initial begin
        // Initialize
        rst_n = 0;
        in_valid = 0;
        in_data0 = 0;  in_data1  = 0; in_data2  = 0;  in_data3 = 0;
        in_data4 = 0;  in_data5  = 0; in_data6  = 0;  in_data7 = 0;
        in_data8 = 0;  in_data9  = 0; in_data10 = 0; in_data11 = 0;
        in_data12 = 0; in_data13 = 0; in_data14 = 0; in_data15 = 0;
        fifo_empty = 1;
        fifo_batch_ready = 0;
        fifo_last_batch = 0;
        pixel_cnt = 0;
        batch_cnt = 0;
        output_cnt = 0;

        // Open trace file
        f_trace = $fopen("trace_l3_tb.txt", "w");
        if (f_trace == 0) begin
            $display("ERROR: Cannot open trace file");
            $finish;
        end

        // Reset
        #20;
        rst_n = 1;
        #10;

        $display("=== L3 Testbench: Batch Reading Strategy ===");
        $display("Total pixels: %d, Batch size: %d, Number of batches: %d",
                 TOTAL_PIXELS, BATCH_SIZE, TOTAL_PIXELS / BATCH_SIZE);

        for (batch_cnt = 0; batch_cnt < 7; batch_cnt = batch_cnt + 1) begin
            #100;
            fifo_batch_ready = 1;
            fifo_empty = 0;
            $display("[TB] Batch %d ready, starting to send pixels %d-%d",
                     batch_cnt, batch_cnt * BATCH_SIZE, (batch_cnt + 1) * BATCH_SIZE - 1);

            for (pixel_cnt = 0; pixel_cnt < BATCH_SIZE; pixel_cnt = pixel_cnt + 1) begin
                @(posedge clk);
                repeat(5) @(posedge clk);

                in_data0  = (batch_cnt * BATCH_SIZE + pixel_cnt) % 256;
                in_data1  = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 2) % 256;
                in_data2  = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 3) % 256;
                in_data3  = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 4) % 256;
                in_data4  = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 5) % 256;
                in_data5  = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 6) % 256;
                in_data6  = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 7) % 256;
                in_data7  = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 8) % 256;
                in_data8  = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 9) % 256;
                in_data9  = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 10) % 256;
                in_data10 = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 11) % 256;
                in_data11 = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 12) % 256;
                in_data12 = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 13) % 256;
                in_data13 = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 14) % 256;
                in_data14 = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 15) % 256;
                in_data15 = ((batch_cnt * BATCH_SIZE + pixel_cnt) * 16) % 256;
                in_valid  = 1;

                @(posedge clk);
                in_valid = 0;
            end

            if (batch_cnt == 6) begin
                fifo_last_batch = 1;
                $display("[TB] Last batch sent");
            end

            #20;
        end

        $display("[TB] All batches sent, waiting for L3 to finish...");
        #100000;

        $display("[TB] Total outputs received: %d (expected: %d pixels, each with %d channels)",
                 output_cnt, IMG_W * IMG_H, CH_OUT);

        $fclose(f_trace);
        $display("[TB] Test completed");
        $finish;
    end

    // Monitor outputs
    always @(posedge clk) begin
        if (out_valid) begin
            output_cnt = output_cnt + 1;
            $fwrite(f_trace, "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
                    out_conv0,  out_conv1,  out_conv2,  out_conv3,  out_conv4,  out_conv5,  out_conv6,  out_conv7,
                    out_conv8,  out_conv9,  out_conv10, out_conv11, out_conv12, out_conv13, out_conv14, out_conv15,
                    out_conv16, out_conv17, out_conv18, out_conv19, out_conv20, out_conv21, out_conv22, out_conv23,
                    out_conv24, out_conv25, out_conv26, out_conv27, out_conv28, out_conv29, out_conv30, out_conv31);

            if (output_cnt <= 5 || output_cnt % 100 == 0) begin
                $display("[TB] Output %d: [0]=%d, [15]=%d, [31]=%d",
                         output_cnt, out_conv0, out_conv15, out_conv31);
            end
        end
    end

    // Monitor key signals
    always @(posedge clk) begin
        if (rd_en_out && $time < 5000) begin
            $display("[TB] rd_en_out=1, calc_busy=%d, fifo_batch_ready=%d, fifo_last_batch=%d",
                     calc_busy_out, fifo_batch_ready, fifo_last_batch);
        end
        if (in_valid && $time < 5000) begin
            $display("[TB] in_valid=1, data[0]=%d, pixel_cnt=%d", in_data0, pixel_cnt);
        end
        if (out_valid) begin
            if (output_cnt <= 10 || output_cnt % 50 == 0) begin
                $display("[TB] out_valid=1, output_cnt=%d", output_cnt);
            end
        end
    end

    // Timeout
    initial begin
        #1000000;
        $display("[TB] TIMEOUT: Simulation took too long");
        $finish;
    end

endmodule

`timescale 1ns/1ps

module conv2d_layer1_tb;

    // Test parameters
    localparam PADDING = 1;
    localparam IMG_W   = 4;
    localparam IMG_H   = 4;
    localparam CH_IN   = 1;
    localparam CH_OUT  = 8;

    reg         clk;
    reg         rst_n;
    reg         in_valid;
    reg  [7:0]  in_data;
    wire        out_valid;
    wire [7:0]  out_conv0;
    wire [7:0]  out_conv1;
    wire [7:0]  out_conv2;
    wire [7:0]  out_conv3;
    wire [7:0]  out_conv4;
    wire [7:0]  out_conv5;
    wire [7:0]  out_conv6;
    wire [7:0]  out_conv7;

    // DUT instance
    conv2d_layer1 #(
        .PADDING(PADDING),
        .IMG_W  (IMG_W),
        .IMG_H  (IMG_H),
        .CH_IN  (CH_IN),
        .CH_OUT (CH_OUT)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (in_valid),
        .in_data  (in_data),
        .out_valid(out_valid),
        .out_conv0(out_conv0),
        .out_conv1(out_conv1),
        .out_conv2(out_conv2),
        .out_conv3(out_conv3),
        .out_conv4(out_conv4),
        .out_conv5(out_conv5),
        .out_conv6(out_conv6),
        .out_conv7(out_conv7)
    );

    // Simple 4x4 image buffer
    reg [7:0] img [0:IMG_W*IMG_H-1];

    integer r, c;
    integer idx;

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 100 MHz clock
    end

    // Monitor outputs
    always @(posedge clk) begin
        if (out_valid) begin
            $display("t=%0t out_conv0=%0d out_conv1=%0d out_conv2=%0d out_conv3=%0d out_conv4=%0d out_conv5=%0d out_conv6=%0d out_conv7=%0d",
                     $time, out_conv0, out_conv1, out_conv2, out_conv3,
                     out_conv4, out_conv5, out_conv6, out_conv7);
        end
    end

    initial begin
        $display("--------------------------------");
        $display("Test started");
        $display("--------------------------------");
        // Initialize image with simple pattern:
        // row0:  1  2  3  4
        // row1:  5  6  7  8
        // row2:  9 10 11 12
        // row3: 13 14 15 16
        for (r = 0; r < IMG_H; r = r + 1) begin
            for (c = 0; c < IMG_W; c = c + 1) begin
                img[r*IMG_W + c] = r*IMG_W + c + 1;
            end
        end

        // Reset
        rst_n    = 1'b0;
        in_valid = 1'b0;
        in_data  = 8'd0;

        #20;
        rst_n = 1'b1;
        #20;

        // Override weights inside DUT:
        // set kernel 0 (for channel 0) to all ones, others zero
        // weight_data[0..8] = 1, others = 0
        for (idx = 0; idx < dut.WEIGHT_SIZE; idx = idx + 1) begin
            dut.weight_data[idx] = 8'sd0;
        end
        for (idx = 0; idx < 9; idx = idx + 1) begin
            dut.weight_data[idx] = 8'sd1;
        end

        // Start streaming image with padding = 1
        in_valid = 1'b1;

        // For each image row
        for (r = 0; r < IMG_H; r = r + 1) begin
            // Left padding
            in_data = 8'd0;
            for (c = 0; c < PADDING; c = c + 1) begin
                @(posedge clk);
            end

            // Active pixels
            for (c = 0; c < IMG_W; c = c + 1) begin
                in_data = img[r*IMG_W + c];
                @(posedge clk);
            end

            // Right padding
            in_data = 8'd0;
            for (c = 0; c < PADDING; c = c + 1) begin
                @(posedge clk);
            end
        end

        // Extra bottom padding row(s) to flush windows
        in_data = 8'd0;
        for (r = 0; r < PADDING; r = r + 1) begin
            for (c = 0; c < (IMG_W + 2*PADDING); c = c + 1) begin
                @(posedge clk);
            end
        end

        // Stop input
        in_valid = 1'b0;
        in_data  = 8'd0;

        // Wait some cycles to observe outputs
        #1000;
        $display("--------------------------------");
        $display("Test finished");
        $display("--------------------------------");
        $finish;
    end

endmodule
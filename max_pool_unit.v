`timescale 1ns/1ps

module max_pool_unit #(
    parameter IMG_W = 28,
    parameter IMG_H = 28
)(
    input                   clk,
    input                   rst_n,
    input                   in_valid,
    input      signed [7:0] in_data,
    output reg              out_valid,
    output reg signed [7:0] out_data
);

    // ============================================================
    // Verilog-2001 Helper Function: clog2
    // ============================================================
    function integer clog2;
        input integer value;
        begin
            value = value - 1;
            for (clog2 = 0; value > 0; clog2 = clog2 + 1)
                value = value >> 1;
        end
    endfunction

    // Use the function to calculate widths
    localparam HALF_W = IMG_W / 2;
    // IMG_W=28 -> clog2(28)=5. Width needs to be [4:0].
    localparam COL_BITS = clog2(IMG_W);
    localparam ROW_BITS = clog2(IMG_H);

    // Line Buffer
    reg signed [7:0] line_buf [0:HALF_W-1];

    // Counters (Use localparams for width)
    reg [COL_BITS-1:0] col_cnt; // [4:0] for 28
    reg [ROW_BITS-1:0] row_cnt;

    // Temporary storage
    reg signed [7:0] left_pixel_val;
    reg signed [7:0] h_max;
    reg signed [7:0] upper_max;

    // Helpers
    wire end_of_line = (col_cnt == IMG_W - 1);
    wire is_odd_row  = row_cnt[0];
    wire is_odd_col  = col_cnt[0];

    // Buffer Index Logic
    // Using simple shift instead of width dependent math
    // Ensure buf_idx width is sufficient
    wire [COL_BITS-2:0] buf_idx = col_cnt[COL_BITS-1:1]; // Equivalent to >> 1

    // ============================================================
    // 1. Counter Logic
    // ============================================================
    // FIX: Allow counters to continue during flush period
    // Extend flush range to start much earlier, ensuring all outputs are generated
    // Start flushing when row_cnt >= 20 to catch all outputs, even if in_valid stops early
    // This ensures we can continue counting to row_cnt=27 and output all 196 pixels
    // FIX: Flush only when we're in the valid output range (row_cnt 1-27 for odd rows)
    // Start flushing when row_cnt >= 20 to ensure we can reach row_cnt=27
    // But limit to row_cnt <= 27 to prevent extra outputs beyond valid range
    wire need_flush_mp = !in_valid && (row_cnt >= IMG_H - 8 && row_cnt <= IMG_H - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 0;
            row_cnt <= 0;
        end else if (in_valid || need_flush_mp) begin
            // Only update counters if we haven't completed all outputs
            // Stop counting when row_cnt reaches 27 and col_cnt reaches 27 (last valid position)
            if (row_cnt < IMG_H - 1 || (row_cnt == IMG_H - 1 && col_cnt < IMG_W - 1)) begin
                if (end_of_line) begin
                    col_cnt <= 0;
                    // Limit row_cnt to IMG_H - 1 (27) to prevent extra outputs
                    if (row_cnt >= IMG_H - 1)
                        row_cnt <= IMG_H - 1;  // Keep at 27, don't increment further
                    else
                        row_cnt <= row_cnt + 1;
                end else begin
                    col_cnt <= col_cnt + 1;
                end
            end
            // else: row_cnt == 27 && col_cnt == 27, stop counting (all outputs generated)
        end
    end

    // ============================================================
    // 2. Max Pooling Logic
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 0;
            out_data  <= 0;
            left_pixel_val <= 0;
        end else if (in_valid || need_flush_mp) begin
            out_valid <= 0;

            // During flush, we still need to process to output buffered data
            // Only process if we have valid data (odd row and odd col) or in_valid is true
            // IMPORTANT: Only output when row_cnt <= IMG_H - 1 (27) and col_cnt < IMG_W (28) to prevent extra outputs
            // Also ensure we only output once per valid position
            if (in_valid || (need_flush_mp && is_odd_row && is_odd_col && row_cnt <= IMG_H - 1 && col_cnt < IMG_W)) begin
                if (!is_odd_col) begin
                    // Even Column: Store current pixel
                    // During flush, keep previous left_pixel_val (don't overwrite with 0)
                    if (in_valid) begin
                        left_pixel_val <= in_data;
                    end
                    // else: keep left_pixel_val unchanged during flush
                end else begin
                    // Odd Column: Compare
                    // h_max = max(left, current)
                    // Note: No $signed needed here as variables are declared signed
                    // During flush, use left_pixel_val (from previous cycle) and 0 for current
                    h_max = ($signed(in_valid ? in_data : 0) > $signed(left_pixel_val)) ? (in_valid ? in_data : 0) : left_pixel_val;

                    if (!is_odd_row) begin
                        // Even Row: Store to Line Buffer
                        line_buf[buf_idx] <= h_max;
                    end else begin
                        // Odd Row: Compare with Buffer
                        upper_max = line_buf[buf_idx];

                        // Final Comparison
                        // During flush, h_max might be 0, but upper_max should have valid data
                        out_data <= ($signed(h_max) > $signed(upper_max)) ? h_max : upper_max;
                        // Output when we have odd row and odd col, and either in_valid or need_flush_mp
                        out_valid <= 1;
                    end
                end
            end
        end else begin
            out_valid <= 0;
        end
    end

endmodule
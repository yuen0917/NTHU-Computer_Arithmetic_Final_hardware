`timescale 1ns/1ps
module conv2d_layer3 #(
    parameter PADDING     = 1,
    parameter IMG_W       = 14,
    parameter IMG_H       = 14,
    parameter CH_IN       = 16,
    parameter CH_OUT      = 32,
    parameter QUANT_SHIFT = 7
)(
    input clk,
    input rst_n,
    input in_valid,
    // 16 Input Channels
    input [7:0] in_data0,  input [7:0] in_data1,  input [7:0] in_data2,  input [7:0] in_data3,
    input [7:0] in_data4,  input [7:0] in_data5,  input [7:0] in_data6,  input [7:0] in_data7,
    input [7:0] in_data8,  input [7:0] in_data9,  input [7:0] in_data10, input [7:0] in_data11,
    input [7:0] in_data12, input [7:0] in_data13, input [7:0] in_data14, input [7:0] in_data15,
    // FIFO status signal
    input fifo_empty,
    input fifo_batch_ready,
    input fifo_last_batch,

    output reg out_valid,
    output calc_busy_out,
    output rd_en_out,
    // 32 Output Channels
    output reg signed [7:0] out_conv0,  output reg signed [7:0] out_conv1,  output reg signed [7:0] out_conv2,  output reg signed [7:0] out_conv3,
    output reg signed [7:0] out_conv4,  output reg signed [7:0] out_conv5,  output reg signed [7:0] out_conv6,  output reg signed [7:0] out_conv7,
    output reg signed [7:0] out_conv8,  output reg signed [7:0] out_conv9,  output reg signed [7:0] out_conv10, output reg signed [7:0] out_conv11,
    output reg signed [7:0] out_conv12, output reg signed [7:0] out_conv13, output reg signed [7:0] out_conv14, output reg signed [7:0] out_conv15,
    output reg signed [7:0] out_conv16, output reg signed [7:0] out_conv17, output reg signed [7:0] out_conv18, output reg signed [7:0] out_conv19,
    output reg signed [7:0] out_conv20, output reg signed [7:0] out_conv21, output reg signed [7:0] out_conv22, output reg signed [7:0] out_conv23,
    output reg signed [7:0] out_conv24, output reg signed [7:0] out_conv25, output reg signed [7:0] out_conv26, output reg signed [7:0] out_conv27,
    output reg signed [7:0] out_conv28, output reg signed [7:0] out_conv29, output reg signed [7:0] out_conv30, output reg signed [7:0] out_conv31
);

    // =========================================================================
    // 1. Input Flattening & Output Buffers
    // =========================================================================
    wire [7:0] in_data [0:15];
    assign in_data[0]  = in_data0;  assign in_data[1]  = in_data1;  assign in_data[2]  = in_data2;  assign in_data[3]  = in_data3;
    assign in_data[4]  = in_data4;  assign in_data[5]  = in_data5;  assign in_data[6]  = in_data6;  assign in_data[7]  = in_data7;
    assign in_data[8]  = in_data8;  assign in_data[9]  = in_data9;  assign in_data[10] = in_data10; assign in_data[11] = in_data11;
    assign in_data[12] = in_data12; assign in_data[13] = in_data13; assign in_data[14] = in_data14; assign in_data[15] = in_data15;

    reg signed [7:0] out_buf [0:31];

    // =========================================================================
    // 2. Control Signals & Input Processing
    // =========================================================================
    reg [4:0] col_cnt;
    reg [4:0] row_cnt;
    reg in_valid_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) in_valid_d1 <= 0;
        else        in_valid_d1 <= in_valid;
    end

    reg processing_started;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) processing_started <= 0;
        else if (fifo_batch_ready || processing_started) processing_started <= 1;
    end

    wire   in_valid_effective;
    assign in_valid_effective = in_valid;

    wire   need_flush_l3;
    assign need_flush_l3 = !in_valid && (row_cnt >= IMG_H - 4 && row_cnt <= IMG_H + 1) && processing_started;

    reg    catch_up_mode;

    wire   calc_busy;

    wire   counter_enable;
    assign counter_enable = (!calc_busy) && (in_valid || (processing_started && row_cnt <= IMG_H + 1)) ||
                            need_flush_l3 ||
                            (catch_up_mode && row_cnt <= IMG_H + 1);

    // =========================================================================
    // 3. Line Buffers & Window Generators
    // =========================================================================
    wire [7:0] r0 [0:15]; wire [7:0] r1 [0:15]; wire [7:0] r2 [0:15];
    wire [7:0] win00 [0:15]; wire [7:0] win01 [0:15]; wire [7:0] win02 [0:15];
    wire [7:0] win10 [0:15]; wire [7:0] win11 [0:15]; wire [7:0] win12 [0:15];
    wire [7:0] win20 [0:15]; wire [7:0] win21 [0:15]; wire [7:0] win22 [0:15];

    genvar i;
    generate
        for (i = 0; i < CH_IN; i = i + 1) begin : ch_inst
            line_buffer lb (
                .clk(clk), .rst_n(rst_n), .in_data(in_data[i]), .in_valid(in_valid_effective),
                .out_row0(r0[i]), .out_row1(r1[i]), .out_row2(r2[i])
            );
            window_generator wg (
                .clk(clk), .rst_n(rst_n), .in_valid(in_valid_effective),
                .r0(r0[i]), .r1(r1[i]), .r2(r2[i]),
                .win00(win00[i]), .win01(win01[i]), .win02(win02[i]),
                .win10(win10[i]), .win11(win11[i]), .win12(win12[i]),
                .win20(win20[i]), .win21(win21[i]), .win22(win22[i])
            );
        end
    endgenerate

    // =========================================================================
    // 4. Coordinates & Trigger Logic
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 0;
            row_cnt <= 0;
        end else if (counter_enable) begin
            if (col_cnt >= IMG_W - 1) begin
                col_cnt <= 0;
                if (row_cnt >= IMG_H + 1) row_cnt <= IMG_H + 1;
                else                      row_cnt <= row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end
        end
    end

    wire   start_trigger_raw;
    wire   start_trigger;
    assign start_trigger = start_trigger_raw;

    localparam [2:0] STATE_IDLE   = 3'b000;
    localparam [2:0] STATE_CALC   = 3'b001;
    localparam [2:0] STATE_DRAIN  = 3'b010;
    localparam [2:0] STATE_OUTPUT = 3'b011;
    reg [2:0] state;
    reg [2:0] next_state;

    assign calc_busy = (state == STATE_CALC || state == STATE_DRAIN || state == STATE_OUTPUT);

    wire   valid_range_row;
    assign valid_range_row = (row_cnt >= 2 && row_cnt <= IMG_H + 1) && (col_cnt < IMG_W);

    wire   flush_range;
    assign flush_range = (row_cnt == IMG_H + 1) && (col_cnt < IMG_W);

    wire   has_valid_data;
    assign has_valid_data = in_valid || (processing_started && (valid_range_row || flush_range)) || need_flush_l3;

    reg    calc_busy_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) calc_busy_d <= 0;
        else        calc_busy_d <= calc_busy;
    end

    wire   calc_busy_falling;
    assign calc_busy_falling = calc_busy_d && !calc_busy;

    reg [7:0] catch_up_row_cnt;
    reg [7:0] catch_up_col_cnt;
    reg [7:0] busy_start_row_cnt;
    reg [7:0] busy_start_col_cnt;

    wire   skipped_positions;
    assign skipped_positions = calc_busy_falling && (row_cnt > busy_start_row_cnt + 1);

    assign start_trigger_raw = ((valid_range_row || flush_range) && (!calc_busy) && has_valid_data && !catch_up_mode) ||
                               (calc_busy_falling && (valid_range_row || flush_range) && has_valid_data && !catch_up_mode) ||
                               (skipped_positions && (valid_range_row || flush_range) && has_valid_data && !catch_up_mode);

    wire   need_catch_up;
    assign need_catch_up = (catch_up_row_cnt < row_cnt) ||
                           (catch_up_row_cnt == row_cnt && catch_up_col_cnt <= col_cnt) ||
                           (catch_up_row_cnt < IMG_H + 1 && catch_up_row_cnt >= 2 && row_cnt >= IMG_H);

    wire   catch_up_valid;
    assign catch_up_valid = catch_up_row_cnt >= 2 && catch_up_row_cnt <= IMG_H + 1 && catch_up_col_cnt < IMG_W &&
                            ((catch_up_row_cnt < row_cnt) || (catch_up_row_cnt == row_cnt && catch_up_col_cnt <= col_cnt) ||
                             (catch_up_row_cnt < IMG_H + 1 && catch_up_row_cnt >= 2 && row_cnt >= IMG_H));

    // =========================================================================
    // 5. Masking & Window Latching
    // =========================================================================
    wire   mask_left;
    assign mask_left = (col_cnt == 1);

    wire   mask_right;
    assign mask_right = (col_cnt == 0);

    wire   mask_top;
    assign mask_top = (row_cnt == 1);

    wire   mask_bottom;
    assign mask_bottom = (row_cnt == IMG_H);

    reg [7:0] latch_win00 [0:15]; reg [7:0] latch_win01 [0:15]; reg [7:0] latch_win02 [0:15];
    reg [7:0] latch_win10 [0:15]; reg [7:0] latch_win11 [0:15]; reg [7:0] latch_win12 [0:15];
    reg [7:0] latch_win20 [0:15]; reg [7:0] latch_win21 [0:15]; reg [7:0] latch_win22 [0:15];

    integer k;
    always @(posedge clk) begin
        if (start_trigger) begin
            for (k=0; k<16; k=k+1) begin
                latch_win00[k] <= (mask_left || mask_top)     ? 0 : win00[k];
                latch_win01[k] <= (mask_top)                  ? 0 : win01[k];
                latch_win02[k] <= (mask_right || mask_top)    ? 0 : win02[k];
                latch_win10[k] <= (mask_left)                 ? 0 : win10[k];
                latch_win11[k] <= win11[k];
                latch_win12[k] <= (mask_right)                ? 0 : win12[k];
                latch_win20[k] <= (mask_left || mask_bottom)  ? 0 : win20[k];
                latch_win21[k] <= (mask_bottom)               ? 0 : win21[k];
                latch_win22[k] <= (mask_right || mask_bottom) ? 0 : win22[k];
            end
        end
    end

    // =========================================================================
    // 6. Folding Architecture State Machine (FIXED STANDARD FSM)
    // =========================================================================
    reg [5:0] mac_cnt;
    reg [2:0] drain_cnt;

    assign calc_busy_out = calc_busy;
    assign rd_en_out = !calc_busy && (fifo_batch_ready || fifo_last_batch || processing_started);

    reg [8:0] output_cnt;
    reg [7:0] saved_row_cnt;
    reg [7:0] saved_col_cnt;

    // -------------------------------------------------------------------------
    // Part 1: State Register Update (Sequential)
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= STATE_IDLE;
        else        state <= next_state;
    end

    // -------------------------------------------------------------------------
    // Part 2: Next State Logic (Combinational)
    // -------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: begin
                if (catch_up_mode && catch_up_valid) begin
                    next_state = STATE_CALC;
                end else if (start_trigger && !catch_up_mode) begin
                    next_state = STATE_CALC;
                end
            end

            STATE_CALC: begin
                if (mac_cnt == 31) begin
                    next_state = STATE_DRAIN;
                end
            end

            STATE_DRAIN: begin
                if (drain_cnt == 4) begin
                    next_state = STATE_OUTPUT;
                end
            end

            STATE_OUTPUT: begin
                next_state = STATE_IDLE;
            end

            default: next_state = STATE_IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // Part 3: Datapath & Counter Control (Sequential)
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mac_cnt            <= 0;
            drain_cnt          <= 0;
            saved_row_cnt      <= 0;
            saved_col_cnt      <= 0;
            busy_start_row_cnt <= 0;
            busy_start_col_cnt <= 0;
            catch_up_mode      <= 0;
            catch_up_row_cnt   <= 0;
            catch_up_col_cnt   <= 0;
            output_cnt         <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    mac_cnt   <= 0;
                    drain_cnt <= 0;

                    if (catch_up_mode && catch_up_valid) begin
                        saved_row_cnt      <= catch_up_row_cnt;
                        saved_col_cnt      <= catch_up_col_cnt;
                        busy_start_row_cnt <= catch_up_row_cnt;
                        busy_start_col_cnt <= catch_up_col_cnt;

                        if (catch_up_col_cnt < IMG_W - 1) begin
                            catch_up_col_cnt <= catch_up_col_cnt + 1;
                        end else begin
                            catch_up_col_cnt <= 0;
                            if (catch_up_row_cnt < IMG_H + 1) catch_up_row_cnt <= catch_up_row_cnt + 1;
                            else                              catch_up_mode    <= 0;
                        end
                    end
                    else if (start_trigger && !catch_up_mode) begin
                        saved_row_cnt      <= row_cnt;
                        saved_col_cnt      <= col_cnt;
                        busy_start_row_cnt <= row_cnt;
                        busy_start_col_cnt <= col_cnt;
                    end

                    if (catch_up_mode &&
                        (catch_up_row_cnt > row_cnt ||
                         (catch_up_row_cnt == row_cnt && catch_up_col_cnt > col_cnt) ||
                         catch_up_row_cnt >= IMG_H + 1)) begin
                        catch_up_mode <= 0;
                    end
                end

                STATE_CALC: begin
                    if (mac_cnt < 31) begin
                        mac_cnt <= mac_cnt + 1;
                    end
                end

                STATE_DRAIN: begin
                    if (drain_cnt < 4) begin
                        drain_cnt <= drain_cnt + 1;
                    end
                end

                STATE_OUTPUT: begin
                    if (row_cnt > busy_start_row_cnt + 1 ||
                        (row_cnt == busy_start_row_cnt + 1 && col_cnt > busy_start_col_cnt + 1) ||
                        (row_cnt == busy_start_row_cnt && col_cnt > busy_start_col_cnt + 1)) begin

                        catch_up_mode <= 1;

                        if (row_cnt > busy_start_row_cnt + 1) begin
                            catch_up_row_cnt <= busy_start_row_cnt + 1;
                            catch_up_col_cnt <= 0;
                        end else if (row_cnt == busy_start_row_cnt + 1) begin
                            catch_up_row_cnt <= busy_start_row_cnt + 1;
                            catch_up_col_cnt <= busy_start_col_cnt + 1;
                        end else begin
                            catch_up_row_cnt <= busy_start_row_cnt;
                            catch_up_col_cnt <= busy_start_col_cnt + 1;
                        end
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // 7. Pipeline Control Signals
    // =========================================================================
    reg [5:0] pipe1_ch_idx, pipe2_ch_idx, pipe3_ch_idx;
    reg       pipe1_valid;
    reg       pipe2_valid;
    reg       pipe3_valid;

    always @(posedge clk) begin
        if (state == STATE_CALC && mac_cnt < 32) begin
            pipe1_ch_idx <= mac_cnt;
            pipe1_valid <= 1;
        end else begin
            pipe1_valid <= 0;
        end
        pipe2_ch_idx <= pipe1_ch_idx;
        pipe2_valid  <= pipe1_valid;

        pipe3_ch_idx <= pipe2_ch_idx;
        pipe3_valid  <= pipe2_valid;
    end

    // =========================================================================
    // 7. Weight Loading & Selection
    // =========================================================================

    reg signed [7:0] weight_data [0:4607];

    initial begin
        $readmemh("conv3_gelu.txt", weight_data);
    end

    function [12:0] get_w_idx;
        input [5:0] och;
        input [4:0] ich;
        input [1:0] r;
        input [1:0] c;
        begin
            get_w_idx = och * 144 + ich * 9 + r * 3 + c;
        end
    endfunction

    reg signed [7:0] cur_w00[0:15]; reg signed [7:0] cur_w01[0:15]; reg signed [7:0] cur_w02[0:15];
    reg signed [7:0] cur_w10[0:15]; reg signed [7:0] cur_w11[0:15]; reg signed [7:0] cur_w12[0:15];
    reg signed [7:0] cur_w20[0:15]; reg signed [7:0] cur_w21[0:15]; reg signed [7:0] cur_w22[0:15];

    genvar j;
    generate
        for (j=0; j<16; j=j+1) begin : w_assign
            always @(posedge clk) begin
                cur_w00[j] <= weight_data[get_w_idx(mac_cnt, j, 0, 0)];
                cur_w01[j] <= weight_data[get_w_idx(mac_cnt, j, 0, 1)];
                cur_w02[j] <= weight_data[get_w_idx(mac_cnt, j, 0, 2)];
                cur_w10[j] <= weight_data[get_w_idx(mac_cnt, j, 1, 0)];
                cur_w11[j] <= weight_data[get_w_idx(mac_cnt, j, 1, 1)];
                cur_w12[j] <= weight_data[get_w_idx(mac_cnt, j, 1, 2)];
                cur_w20[j] <= weight_data[get_w_idx(mac_cnt, j, 2, 0)];
                cur_w21[j] <= weight_data[get_w_idx(mac_cnt, j, 2, 1)];
                cur_w22[j] <= weight_data[get_w_idx(mac_cnt, j, 2, 2)];
            end
        end
    endgenerate

    // =========================================================================
    // 8. Pipeline Stage 1: Parallel MAC Units
    // =========================================================================
    wire signed [31:0] mac_res [0:15];
    generate
        for (i = 0; i < 16; i = i + 1) begin : mac_inst
            mac_3x3 #(.INPUT_IS_SIGNED(1)) u_mac (
                .clk(clk), .rst_n(rst_n), .in_valid(calc_busy),
                .win00(latch_win00[i]), .win01(latch_win01[i]), .win02(latch_win02[i]),
                .win10(latch_win10[i]), .win11(latch_win11[i]), .win12(latch_win12[i]),
                .win20(latch_win20[i]), .win21(latch_win21[i]), .win22(latch_win22[i]),
                .weight00(cur_w00[i]),  .weight01(cur_w01[i]),  .weight02(cur_w02[i]),
                .weight10(cur_w10[i]),  .weight11(cur_w11[i]),  .weight12(cur_w12[i]),
                .weight20(cur_w20[i]),  .weight21(cur_w21[i]),  .weight22(cur_w22[i]),
                .out_mac(mac_res[i])
            );
        end
    endgenerate

    // =========================================================================
    // 9. Pipeline Stage 2: Adder Tree & Quantization
    // =========================================================================
    reg signed [31:0] sum_all_ch;
    reg signed [ 7:0] quant_out;
    integer m;

    always @(*) begin
        sum_all_ch = 0;
        for (m = 0; m < 16; m = m + 1) begin
            sum_all_ch = sum_all_ch + mac_res[m];
        end

        if (sum_all_ch >>> QUANT_SHIFT > 127)       quant_out = 127;
        else if (sum_all_ch >>> QUANT_SHIFT < -128) quant_out = -128;
        else                                        quant_out = sum_all_ch >>> QUANT_SHIFT;
    end

    // =========================================================================
    // 10. Pipeline Stage 3: Activation (GELU) & Buffering
    // =========================================================================
    wire [7:0] gelu_out_wire;
    wire       gelu_valid_wire;

    gelu_lut_act u_gelu (
        .clk(clk), .rst_n(rst_n),
        .in_valid(pipe2_valid),
        .in_data(quant_out),
        .out_valid(gelu_valid_wire),
        .out_data(gelu_out_wire)
    );

    always @(posedge clk) begin
        if (gelu_valid_wire) begin
            out_buf[pipe3_ch_idx] <= gelu_out_wire;
        end
    end

    // =========================================================================
    // 11. Final Output Driver
    // =========================================================================
    reg drain_cnt_3_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) drain_cnt_3_d <= 0;
        else        drain_cnt_3_d <= (calc_busy && mac_cnt == 31 && drain_cnt == 3);
    end

    wire calc_busy_output_pulse;
    assign calc_busy_output_pulse = (calc_busy && mac_cnt == 31 && drain_cnt == 4) && drain_cnt_3_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid  <= 0;
            out_conv0  <= 0; out_conv1  <= 0; out_conv2  <= 0; out_conv3  <= 0;
            out_conv4  <= 0; out_conv5  <= 0; out_conv6  <= 0; out_conv7  <= 0;
            out_conv8  <= 0; out_conv9  <= 0; out_conv10 <= 0; out_conv11 <= 0;
            out_conv12 <= 0; out_conv13 <= 0; out_conv14 <= 0; out_conv15 <= 0;
            out_conv16 <= 0; out_conv17 <= 0; out_conv18 <= 0; out_conv19 <= 0;
            out_conv20 <= 0; out_conv21 <= 0; out_conv22 <= 0; out_conv23 <= 0;
            out_conv24 <= 0; out_conv25 <= 0; out_conv26 <= 0; out_conv27 <= 0;
            out_conv28 <= 0; out_conv29 <= 0; out_conv30 <= 0; out_conv31 <= 0;
        end else begin
            if (calc_busy_output_pulse) begin
                if (saved_row_cnt >= 2 && saved_row_cnt <= IMG_H + 1 && saved_col_cnt < IMG_W && output_cnt < 196) begin
                    out_valid  <= 1;
                    output_cnt <= output_cnt + 1;
                    out_conv0  <= out_buf[0];  out_conv1  <= out_buf[1];  out_conv2  <= out_buf[2];  out_conv3  <= out_buf[3];
                    out_conv4  <= out_buf[4];  out_conv5  <= out_buf[5];  out_conv6  <= out_buf[6];  out_conv7  <= out_buf[7];
                    out_conv8  <= out_buf[8];  out_conv9  <= out_buf[9];  out_conv10 <= out_buf[10]; out_conv11 <= out_buf[11];
                    out_conv12 <= out_buf[12]; out_conv13 <= out_buf[13]; out_conv14 <= out_buf[14]; out_conv15 <= out_buf[15];
                    out_conv16 <= out_buf[16]; out_conv17 <= out_buf[17]; out_conv18 <= out_buf[18]; out_conv19 <= out_buf[19];
                    out_conv20 <= out_buf[20]; out_conv21 <= out_buf[21]; out_conv22 <= out_buf[22]; out_conv23 <= out_buf[23];
                    out_conv24 <= out_buf[24]; out_conv25 <= out_buf[25]; out_conv26 <= out_buf[26]; out_conv27 <= out_buf[27];
                    out_conv28 <= out_buf[28]; out_conv29 <= out_buf[29]; out_conv30 <= out_buf[30]; out_conv31 <= out_buf[31];
                end else begin
                    out_valid <= 0;
                end
            end else begin
                out_valid <= 0;
            end
        end
    end
endmodule
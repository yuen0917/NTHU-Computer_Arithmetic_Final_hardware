`timescale 1ns/1ps

module conv2d_layer2_tb;

    // ============================================================
    // 1. 參數設定
    // ============================================================
    // 為了測試方便，我們使用 4x4 的小圖
    parameter PADDING     = 1;
    parameter IMG_W       = 4;
    parameter IMG_H       = 4;
    parameter CH_IN       = 8;
    parameter CH_OUT      = 16;

    // 注意：測試時將 QUANT_SHIFT 設為 0，避免數值太小被右移成 0
    parameter QUANT_SHIFT = 0;

    // ============================================================
    // 權重測試參數（可修改此處來測試不同權重）
    // ============================================================
    // 預設權重值：可以修改這些值來測試不同的權重
    // 對於多通道卷積，每個輸出通道對每個輸入通道都有權重
    // 這裡簡化為：所有輸入通道使用相同權重值
    parameter WEIGHT_BASE = 1;  // 基礎權重值（可修改）

    // 權重陣列：weight[output_channel][input_channel]
    reg signed [7:0] test_weights [0:CH_OUT-1][0:CH_IN-1];

    // ============================================================
    // SELU LUT（與主程式相同的方式）
    // ============================================================
    reg signed [7:0] selu_lut [0:255];

    initial begin
        $readmemh("selu_lut.txt", selu_lut);
        $display("[TB Info] SELU LUT loaded from selu_lut.txt");
    end

    // ============================================================
    // 2. 訊號宣告
    // ============================================================
    reg          clk;
    reg          rst_n;
    reg          in_valid;
    reg  [7:0]   in_data0;
    reg  [7:0]   in_data1;
    reg  [7:0]   in_data2;
    reg  [7:0]   in_data3;
    reg  [7:0]   in_data4;
    reg  [7:0]   in_data5;
    reg  [7:0]   in_data6;
    reg  [7:0]   in_data7;

    wire         out_valid;
    wire [7:0]   out_conv0;
    wire [7:0]   out_conv1;
    wire [7:0]   out_conv2;
    wire [7:0]   out_conv3;
    wire [7:0]   out_conv4;
    wire [7:0]   out_conv5;
    wire [7:0]   out_conv6;
    wire [7:0]   out_conv7;
    wire [7:0]   out_conv8;
    wire [7:0]   out_conv9;
    wire [7:0]   out_conv10;
    wire [7:0]   out_conv11;
    wire [7:0]   out_conv12;
    wire [7:0]   out_conv13;
    wire [7:0]   out_conv14;
    wire [7:0]   out_conv15;

    // 方便迴圈存取的 Array
    wire [7:0]   out_conv_array [0:CH_OUT-1];
    assign out_conv_array[0]  = out_conv0;
    assign out_conv_array[1]  = out_conv1;
    assign out_conv_array[2]  = out_conv2;
    assign out_conv_array[3]  = out_conv3;
    assign out_conv_array[4]  = out_conv4;
    assign out_conv_array[5]  = out_conv5;
    assign out_conv_array[6]  = out_conv6;
    assign out_conv_array[7]  = out_conv7;
    assign out_conv_array[8]  = out_conv8;
    assign out_conv_array[9]  = out_conv9;
    assign out_conv_array[10] = out_conv10;
    assign out_conv_array[11] = out_conv11;
    assign out_conv_array[12] = out_conv12;
    assign out_conv_array[13] = out_conv13;
    assign out_conv_array[14] = out_conv14;
    assign out_conv_array[15] = out_conv15;

    // 輸入資料陣列（8 個通道）
    reg  [7:0]   in_data_array [0:CH_IN-1];
    assign in_data0 = in_data_array[0];
    assign in_data1 = in_data_array[1];
    assign in_data2 = in_data_array[2];
    assign in_data3 = in_data_array[3];
    assign in_data4 = in_data_array[4];
    assign in_data5 = in_data_array[5];
    assign in_data6 = in_data_array[6];
    assign in_data7 = in_data_array[7];

    // 測試資料儲存區
    reg  [7:0]   input_img [0:CH_IN-1][0:IMG_H*IMG_W-1];  // 8 個通道的輸入影像
    reg  [7:0]   golden_out [0:CH_OUT-1][0:IMG_H*IMG_W-1]; // 16 個通道的預期答案

    // 迴圈變數
    integer i, j, k;
    integer r, c;
    integer out_ch, in_ch;
    integer out_cnt;
    integer err_cnt;

    // ============================================================
    // 3. DUT (Device Under Test) 實例化
    // ============================================================
    conv2d_layer2 #(
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
        .in_data0   (in_data0),
        .in_data1   (in_data1),
        .in_data2   (in_data2),
        .in_data3   (in_data3),
        .in_data4   (in_data4),
        .in_data5   (in_data5),
        .in_data6   (in_data6),
        .in_data7   (in_data7),
        .out_valid  (out_valid),
        .out_conv0  (out_conv0),
        .out_conv1  (out_conv1),
        .out_conv2  (out_conv2),
        .out_conv3  (out_conv3),
        .out_conv4  (out_conv4),
        .out_conv5  (out_conv5),
        .out_conv6  (out_conv6),
        .out_conv7  (out_conv7),
        .out_conv8  (out_conv8),
        .out_conv9  (out_conv9),
        .out_conv10 (out_conv10),
        .out_conv11 (out_conv11),
        .out_conv12 (out_conv12),
        .out_conv13 (out_conv13),
        .out_conv14 (out_conv14),
        .out_conv15 (out_conv15)
    );

    // ============================================================
    // 4. 時脈產生 (100MHz)
    // ============================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // 5. 權重設定任務（可設定不同通道的權重值）
    // ============================================================
    task set_weights;
        integer out_ch, in_ch, pos;
        integer weight_idx;
        begin
            $display("\n[TB Info] Setting weights...");
            // 清空所有權重
            for (i = 0; i < u_dut.WEIGHT_SIZE; i = i + 1) begin
                u_dut.weight_data[i] = 0;
            end

            // 設定每個 (輸出通道, 輸入通道) 對的權重
            // 權重索引：weight_data[(out_ch * CH_IN + in_ch) * KERNEL_SIZE + kernel_pos]
            for (out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin
                for (in_ch = 0; in_ch < CH_IN; in_ch = in_ch + 1) begin
                    for (pos = 0; pos < 9; pos = pos + 1) begin
                        weight_idx = (out_ch * CH_IN + in_ch) * 9 + pos;
                        u_dut.weight_data[weight_idx] = test_weights[out_ch][in_ch];
                    end
                end
                $display("  Output Channel %0d: weights set", out_ch);
            end
            $display("[TB Info] Weight setting complete.\n");
        end
    endtask

    // ============================================================
    // 6. Golden Model 計算任務（使用實際權重值）
    //    這是軟體演算法，用來算出正確答案
    //    注意：多通道卷積需要對所有輸入通道進行卷積並累加
    // ============================================================
    task calculate_golden;
        reg [7:0] padded_img [0:CH_IN-1][0:IMG_H + 2*PADDING - 1][0:IMG_W + 2*PADDING - 1];
        integer y, x, ky, kx;
        integer sum;
        integer ch_out, ch_in;
        integer pixel_sum;
        integer selu_idx;
        integer selu_result;
        integer scaled_sum;
        begin
            // A. 初始化所有通道的 Padded Image 為 0
            for (ch_in = 0; ch_in < CH_IN; ch_in = ch_in + 1) begin
                for (y = 0; y < IMG_H + 2*PADDING; y = y + 1) begin
                    for (x = 0; x < IMG_W + 2*PADDING; x = x + 1) begin
                        padded_img[ch_in][y][x] = 0;
                    end
                end
            end

            // B. 填入原始影像到中間（每個輸入通道）
            for (ch_in = 0; ch_in < CH_IN; ch_in = ch_in + 1) begin
                for (y = 0; y < IMG_H; y = y + 1) begin
                    for (x = 0; x < IMG_W; x = x + 1) begin
                        padded_img[ch_in][y+PADDING][x+PADDING] = input_img[ch_in][y*IMG_W + x];
                    end
                end
            end

            $display("\n=== GOLDEN MODEL CALCULATION ===");
            $display("Multi-channel convolution: %0d input channels -> %0d output channels", CH_IN, CH_OUT);

            // C. 計算每個輸出通道的結果
            for (ch_out = 0; ch_out < CH_OUT; ch_out = ch_out + 1) begin
                for (y = 0; y < IMG_H; y = y + 1) begin
                    for (x = 0; x < IMG_W; x = x + 1) begin
                        sum = 0;

                        // 對每個輸入通道進行卷積並累加
                        for (ch_in = 0; ch_in < CH_IN; ch_in = ch_in + 1) begin
                            pixel_sum = 0;

                            // 計算 3x3 卷積（權重為 test_weights[ch_out][ch_in]）
                            for (ky = 0; ky < 3; ky = ky + 1) begin
                                for (kx = 0; kx < 3; kx = kx + 1) begin
                                    // 確保有符號運算
                                    pixel_sum = pixel_sum + $signed({1'b0, padded_img[ch_in][y+ky][x+kx]}) * $signed(test_weights[ch_out][ch_in]);
                                end
                            end

                            // 累加所有輸入通道的結果
                            sum = sum + pixel_sum;
                        end

                        // 量化：右移 QUANT_SHIFT 位（與硬體實作一致）
                        scaled_sum = sum >>> QUANT_SHIFT;

                        // 量化後的飽和處理（限制在有符號 8-bit 範圍：-128 ~ 127）
                        // 與主程式中的 selu_in 計算相同
                        if (scaled_sum > 127) begin
                            scaled_sum = 127;
                        end else if (scaled_sum < -128) begin
                            scaled_sum = -128;
                        end

                        // SELU: 使用 LUT 查表（與主程式相同的方式）
                        // 將有符號 8-bit 轉為無符號索引（0~255）
                        // 索引方式：直接使用 8-bit 值作為索引（與 selu_lut_act.v 相同）
                        // selu_lut_act.v: assign idx = in_data; (直接使用 8-bit 值)
                        selu_idx = scaled_sum[7:0];  // 直接使用 8-bit 值作為索引

                        // 查表得到 SELU 結果（selu_lut_act.v 輸出是有符號 8-bit）
                        selu_result = selu_lut[selu_idx];

                        // 主程式中 SELU 輸出直接連接到 out_conv（無符號 8-bit）
                        // 所以需要將有符號轉為無符號
                        // 如果 SELU 輸出是負數，則設為 0（因為最終輸出是無符號）
                        if (selu_result < 0) begin
                            selu_result = 0;
                        end

                        // 飽和處理：超過 255 截斷
                        if (selu_result > 255) begin
                            selu_result = 255;
                        end

                        // 確保輸出為無符號 8-bit 值
                        golden_out[ch_out][y*IMG_W + x] = selu_result[7:0];
                    end
                end
                $display("  Output Channel %0d: Golden model calculated", ch_out);
            end
            $display("=== GOLDEN MODEL COMPLETE ===\n");
        end
    endtask

    // ============================================================
    // 7. 主測試流程
    // ============================================================
    initial begin
        // 波形檔設定 (依你的模擬器選擇)
        $dumpfile("conv2d_layer2_wave.vcd");
        $dumpvars(0, conv2d_layer2_tb);
        // 如果是用 Verdi，可以取消註解下面這行
        // $fsdbDumpfile("conv2d_layer2.fsdb"); $fsdbDumpvars(0, "+all");

        // --------------------------------------------------------
        // A. 初始化測試圖案 (8 個通道，每個通道都是遞增數字)
        // --------------------------------------------------------
        $display("--------------------------------------------------");
        $display(" Start Simulation - Layer 2 Test ");
        $display("--------------------------------------------------");

        // 為每個輸入通道初始化不同的測試圖案
        for (i = 0; i < CH_IN; i = i + 1) begin
            for (j = 0; j < IMG_H*IMG_W; j = j + 1) begin
                // 每個通道使用不同的偏移量，方便區分
                input_img[i][j] = (i + 1) * 10 + (j + 1);
            end
        end

        // --------------------------------------------------------
        // B. 初始化權重值（可在此修改測試不同的權重）
        // --------------------------------------------------------
        // 簡化設定：所有輸出通道對所有輸入通道使用相同權重
        // 可以修改這裡來測試不同的權重組合
        for (out_ch = 0; out_ch < CH_OUT; out_ch = out_ch + 1) begin
            for (in_ch = 0; in_ch < CH_IN; in_ch = in_ch + 1) begin
                // 方式 1: 所有權重相同
                test_weights[out_ch][in_ch] = WEIGHT_BASE;

                // 方式 2: 根據通道設定不同權重（取消註解使用）
                // test_weights[out_ch][in_ch] = (out_ch + 1) * (in_ch + 1);

                // 方式 3: 測試負數權重
                // test_weights[out_ch][in_ch] = -((out_ch + 1) * (in_ch + 1));
            end
        end

        // --------------------------------------------------------
        // C. 計算預期答案（使用實際權重值）
        // --------------------------------------------------------
        calculate_golden();

        // --------------------------------------------------------
        // D. 重置與參數設定
        // --------------------------------------------------------
        rst_n    = 1;
        in_valid = 0;
        for (i = 0; i < CH_IN; i = i + 1) begin
            in_data_array[i] = 0;
        end
        out_cnt  = 0;
        err_cnt  = 0;

        #10 rst_n = 0; // Reset active
        #20 rst_n = 1; // Release reset
        #10;

        // --------------------------------------------------------
        // E. 設定權重到 DUT
        // --------------------------------------------------------
        set_weights();

        // --------------------------------------------------------
        // F. 開始送入資料 (依循 Line Buffer 的 Padding 規則)
        //    注意：需要同時送入 8 個通道的資料
        // --------------------------------------------------------
        $display("[TB Info] Streaming Input Data (8 channels)...");
        in_valid = 1;

        // 逐行送入（8 個通道並行）
        for (r = 0; r < IMG_H; r = r + 1) begin

            // 1. 左邊 Padding
            for (i = 0; i < CH_IN; i = i + 1) begin
                in_data_array[i] = 0;
            end
            for (k = 0; k < PADDING; k = k + 1) @(posedge clk);

            // 2. 有效影像資料
            for (c = 0; c < IMG_W; c = c + 1) begin
                for (i = 0; i < CH_IN; i = i + 1) begin
                    in_data_array[i] = input_img[i][r*IMG_W + c];
                end
                @(posedge clk);
            end

            // 3. 右邊 Padding
            for (i = 0; i < CH_IN; i = i + 1) begin
                in_data_array[i] = 0;
            end
            for (k = 0; k < PADDING; k = k + 1) @(posedge clk);
        end

        // --------------------------------------------------------
        // G. 送入底部 Padding / Flush Pipeline
        //    必須持續送 in_valid = 1 讓 pipeline 把最後的結果推出來
        // --------------------------------------------------------
        for (i = 0; i < CH_IN; i = i + 1) begin
            in_data_array[i] = 0;
        end
        // 大約需要多送幾行 0 來把最後的 window 推算完
        // 考慮 SELU 的額外延遲，可能需要更多週期
        repeat ( (IMG_W + 2*PADDING) * 3 ) @(posedge clk);

        in_valid = 0;

        // 等待所有輸出檢查完畢
        #2000;

        // --------------------------------------------------------
        // H. 總結報告
        // --------------------------------------------------------
        if (out_cnt != IMG_W * IMG_H) begin
            $display("\n[ERROR] Output count mismatch! Expected: %0d, Received: %0d", IMG_W * IMG_H, out_cnt);
            err_cnt = err_cnt + 1;
        end

        if (err_cnt == 0) begin
            $display("\n==================================================");
            $display("  ALL PASS! (Total %0d pixels verified)", out_cnt);
            $display("==================================================\n");
        end else begin
            $display("\n==================================================");
            $display("  FAIL! Found %0d errors.", err_cnt);
            $display("==================================================\n");
        end

        $finish;
    end

    // ============================================================
    // 8. 自動檢查區塊 (Monitor)
    // ============================================================
    always @(posedge clk) begin
        if (out_valid) begin
            if (out_cnt < IMG_W * IMG_H) begin
                // 檢查所有輸出通道
                for (i = 0; i < CH_OUT; i = i + 1) begin
                    if (out_conv_array[i] !== golden_out[i][out_cnt]) begin
                        $display("[FAIL] Ch%02d Idx=%02d | Expected=%3d | Actual=%3d | (Time=%0t)",
                                 i, out_cnt, golden_out[i][out_cnt], out_conv_array[i], $time);
                        err_cnt = err_cnt + 1;
                    end else begin
                        $display("[PASS] Ch%02d Idx=%02d | Expected=%3d | Actual=%3d",
                                 i, out_cnt, golden_out[i][out_cnt], out_conv_array[i]);
                    end
                end
            end
            out_cnt = out_cnt + 1;
        end
    end

endmodule

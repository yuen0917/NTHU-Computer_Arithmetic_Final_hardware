`timescale 1ns/1ps

module conv2d_layer1_tb;

    // ============================================================
    // 1. 參數設定
    // ============================================================
    // 為了測試方便，我們使用 4x4 的小圖
    parameter PADDING     = 1;
    parameter IMG_W       = 4;
    parameter IMG_H       = 4;
    parameter CH_IN       = 1;
    parameter CH_OUT      = 8;

    // 注意：測試時將 QUANT_SHIFT 設為 0，避免數值太小被右移成 0
    parameter QUANT_SHIFT = 0;

    // ============================================================
    // 權重測試參數（可修改此處來測試不同權重）
    // ============================================================
    // 預設權重值：可以修改這些值來測試不同的權重
    parameter WEIGHT_CH0 = -1;  // Channel 0 的權重值
    parameter WEIGHT_CH1 = -2;  // Channel 1 的權重值
    parameter WEIGHT_CH2 = -3;  // Channel 2 的權重值
    parameter WEIGHT_CH3 = -4;  // Channel 3 的權重值
    parameter WEIGHT_CH4 = -5;  // Channel 4 的權重值
    parameter WEIGHT_CH5 = -6;  // Channel 5 的權重值
    parameter WEIGHT_CH6 = -7;  // Channel 6 的權重值
    parameter WEIGHT_CH7 = -8;  // Channel 7 的權重值

    // 或者使用陣列方式（更靈活）
    reg signed [7:0] test_weights [0:7];

    // ============================================================
    // 2. 訊號宣告
    // ============================================================
    reg          clk;
    reg          rst_n;
    reg          in_valid;
    reg  [7:0]   in_data;

    wire         out_valid;
    wire [7:0]   out_conv0;
    wire [7:0]   out_conv1;
    wire [7:0]   out_conv2;
    wire [7:0]   out_conv3;
    wire [7:0]   out_conv4;
    wire [7:0]   out_conv5;
    wire [7:0]   out_conv6;
    wire [7:0]   out_conv7;

    // 方便迴圈存取的 Array
    wire [7:0] out_conv_array [0:7];

    assign out_conv_array[0] = out_conv0;
    assign out_conv_array[1] = out_conv1;
    assign out_conv_array[2] = out_conv2;
    assign out_conv_array[3] = out_conv3;
    assign out_conv_array[4] = out_conv4;
    assign out_conv_array[5] = out_conv5;
    assign out_conv_array[6] = out_conv6;
    assign out_conv_array[7] = out_conv7;

    // 測試資料儲存區
    reg  [7:0]   input_img [0:IMG_H*IMG_W-1];                    // 原始輸入影像
    reg  [7:0]   golden_out [0:CH_OUT-1][0:IMG_H*IMG_W-1];      // 所有通道的預期答案

    // 迴圈變數
    integer i, j, k;
    integer r, c;
    integer out_cnt;
    integer err_cnt;

    // ============================================================
    // 3. DUT (Device Under Test) 實例化
    // ============================================================
    conv2d_layer1 #(
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
        .in_data    (in_data),
        .out_valid  (out_valid),
        .out_conv0  (out_conv0),
        .out_conv1  (out_conv1),
        .out_conv2  (out_conv2),
        .out_conv3  (out_conv3),
        .out_conv4  (out_conv4),
        .out_conv5  (out_conv5),
        .out_conv6  (out_conv6),
        .out_conv7  (out_conv7)
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
        integer ch, pos;
        begin
            $display("\n[TB Info] Setting weights...");
            // 清空所有權重
            for (i = 0; i < u_dut.WEIGHT_SIZE; i = i + 1) begin
                u_dut.weight_data[i] = 0;
            end

            // 設定每個通道的權重（使用 test_weights 陣列）
            for (ch = 0; ch < CH_OUT; ch = ch + 1) begin
                for (pos = 0; pos < 9; pos = pos + 1) begin
                    u_dut.weight_data[ch * 9 + pos] = test_weights[ch];
                end
                $display("  Channel %0d: weight = %0d (all 9 positions)", ch, test_weights[ch]);
            end
            $display("[TB Info] Weight setting complete.\n");
        end
    endtask

    // ============================================================
    // 6. Golden Model 計算任務（使用實際權重值）
    //    這是軟體演算法，用來算出正確答案
    // ============================================================
    task calculate_golden;
        reg [7:0] padded_img [0:IMG_H + 2*PADDING - 1][0:IMG_W + 2*PADDING - 1];
        integer y, x, ky, kx;
        integer sum;
        integer ch;
        begin
            // A. 初始化 Padded Image 為 0
            for (y = 0; y < IMG_H + 2*PADDING; y = y + 1) begin
                for (x = 0; x < IMG_W + 2*PADDING; x = x + 1) begin
                    padded_img[y][x] = 0;
                end
            end

            // B. 填入原始影像到中間
            for (y = 0; y < IMG_H; y = y + 1) begin
                for (x = 0; x < IMG_W; x = x + 1) begin
                    padded_img[y+PADDING][x+PADDING] = input_img[y*IMG_W + x];
                end
            end

            $display("\n=== GOLDEN MODEL CALCULATION ===");
            $display("Using weights: Ch0=%0d, Ch1=%0d, Ch2=%0d, Ch3=%0d, Ch4=%0d, Ch5=%0d, Ch6=%0d, Ch7=%0d",
                     test_weights[0], test_weights[1], test_weights[2], test_weights[3],
                     test_weights[4], test_weights[5], test_weights[6], test_weights[7]);

            // 計算每個通道的輸出
            for (ch = 0; ch < CH_OUT; ch = ch + 1) begin
                for (y = 0; y < IMG_H; y = y + 1) begin
                    for (x = 0; x < IMG_W; x = x + 1) begin
                        sum = 0;

                        // 計算 3x3 卷積（權重全為 test_weights[ch]）
                        // 注意：使用有符號乘法確保負數權重正確計算
                        for (ky = 0; ky < 3; ky = ky + 1) begin
                            for (kx = 0; kx < 3; kx = kx + 1) begin
                                // 確保有符號運算：將無符號的 padded_img 轉為有符號後再乘
                                sum = sum + $signed({1'b0, padded_img[y+ky][x+kx]}) * $signed(test_weights[ch]);
                            end
                        end

                        // ReLU: 如果結果小於 0，則設為 0
                        // 這是 ReLU 激活函數的核心：ReLU(x) = max(0, x)
                        if (sum < 0) begin
                            sum = 0;
                        end

                        // Saturation: 超過 255 截斷到 255
                        if (sum > 255) begin
                            sum = 255;
                        end

                        // 確保輸出為無符號 8-bit 值
                        golden_out[ch][y*IMG_W + x] = sum[7:0];
                    end
                end
                $display("  Channel %0d: Golden model calculated (weight=%0d, ReLU applied)", ch, test_weights[ch]);
            end
            $display("=== GOLDEN MODEL COMPLETE ===\n");
        end
    endtask

    // ============================================================
    // 7. 主測試流程
    // ============================================================
    initial begin
        // 波形檔設定 (依你的模擬器選擇)
        $dumpfile("conv2d_wave.vcd");
        $dumpvars(0, conv2d_layer1_tb);
        // 如果是用 Verdi，可以取消註解下面這行
        // $fsdbDumpfile("conv2d.fsdb"); $fsdbDumpvars(0, "+all");

        // --------------------------------------------------------
        // A. 初始化測試圖案 (遞增數字 1, 2, 3... 16)
        // --------------------------------------------------------
        $display("--------------------------------------------------");
        $display(" Start Simulation ");
        $display("--------------------------------------------------");

        for (i = 0; i < IMG_H*IMG_W; i = i + 1) begin
            input_img[i] = i + 1;
        end

        // --------------------------------------------------------
        // B. 初始化權重值（可在此修改測試不同的權重）
        // --------------------------------------------------------
        // 方式 1: 使用參數值
        test_weights[0] = WEIGHT_CH0;
        test_weights[1] = WEIGHT_CH1;
        test_weights[2] = WEIGHT_CH2;
        test_weights[3] = WEIGHT_CH3;
        test_weights[4] = WEIGHT_CH4;
        test_weights[5] = WEIGHT_CH5;
        test_weights[6] = WEIGHT_CH6;
        test_weights[7] = WEIGHT_CH7;

        // 方式 2: 直接設定（會覆蓋參數值）
        // 範例：測試不同的權重值
        // test_weights[0] = 1;
        // test_weights[1] = 2;
        // test_weights[2] = 3;
        // test_weights[3] = 4;
        // test_weights[4] = 5;
        // test_weights[5] = 6;
        // test_weights[6] = 7;
        // test_weights[7] = 8;

        // 或者測試負數權重
        // test_weights[0] = -1;
        // test_weights[1] = -2;
        // ...

        // --------------------------------------------------------
        // C. 計算預期答案（使用實際權重值）
        // --------------------------------------------------------
        calculate_golden();

        // --------------------------------------------------------
        // D. 重置與參數設定
        // --------------------------------------------------------
        rst_n    = 1;
        in_valid = 0;
        in_data  = 0;
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
        // --------------------------------------------------------
        $display("[TB Info] Streaming Input Data...");
        in_valid = 1;

        // 逐行送入
        for (r = 0; r < IMG_H; r = r + 1) begin

            // 1. 左邊 Padding
            in_data = 0;
            for (k = 0; k < PADDING; k = k + 1) @(posedge clk);

            // 2. 有效影像資料
            for (c = 0; c < IMG_W; c = c + 1) begin
                in_data = input_img[r*IMG_W + c];
                @(posedge clk);
            end

            // 3. 右邊 Padding
            in_data = 0;
            for (k = 0; k < PADDING; k = k + 1) @(posedge clk);
        end

        // --------------------------------------------------------
        // G. 送入底部 Padding / Flush Pipeline
        //    必須持續送 in_valid = 1 讓 pipeline 把最後的結果推出來
        // --------------------------------------------------------
        in_data = 0;
        // 大約需要多送幾行 0 來把最後的 window 推算完
        repeat ( (IMG_W + 2*PADDING) * 2 ) @(posedge clk);

        in_valid = 0;

        // 等待所有輸出檢查完畢
        #1000;

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
                // 檢查所有通道
                for (i = 0; i < CH_OUT; i = i + 1) begin
                    if (out_conv_array[i] !== golden_out[i][out_cnt]) begin
                        $display("[FAIL] Ch%0d Idx=%02d | Expected=%3d | Actual=%3d | Weight=%0d | (Time=%0t)",
                                 i, out_cnt, golden_out[i][out_cnt], out_conv_array[i], test_weights[i], $time);
                        err_cnt = err_cnt + 1;
                    end else begin
                        $display("[PASS] Ch%0d Idx=%02d | Expected=%3d | Actual=%3d | Weight=%0d",
                                 i, out_cnt, golden_out[i][out_cnt], out_conv_array[i], test_weights[i]);
                    end
                end
            end
            out_cnt = out_cnt + 1;
        end
    end

endmodule
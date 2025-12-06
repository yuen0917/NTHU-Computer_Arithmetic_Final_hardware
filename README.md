# Global Average Pooling CNN - FPGA 實作專案

## 專案簡介

本專案旨在將一個用於 MNIST 手寫數字分類的卷積神經網路（CNN）架構實作於 FPGA 上。該 CNN 架構採用 Global Average Pooling（全域平均池化）技術，包含 3 個卷積層、1 個最大池化層、1 個全域平均池化層、1 個全連接層和 1 個 Softmax 層。

## 資料集規格

- **任務**: 手寫數字分類 (0-9, 共 10 類)
- **輸入**: 1×28×28 灰階影像（單通道）
- **資料集**: MNIST
  - 訓練集: 60,000 張
  - 測試集: 10,000 張
- **評估指標**: Top-1 Accuracy

## CNN 架構

### 完整架構流程

1. **Conv2d(1→8, kernel=3, padding=1) → ReLU**
   - 輸入: 1×28×28
   - 輸出: 8×28×28
   - 參數計算: 8 × 1 × 3×3 = 72

2. **Conv2d(8→16, kernel=3, padding=1) → SELU**
   - 輸入: 8×28×28
   - 輸出: 16×28×28
   - 參數計算: 16 × 8 × 3×3 = 1,152

3. **MaxPool 2×2 (stride=2)**
   - 輸入: 16×28×28
   - 輸出: 16×14×14
   - 對每個 2×2 區塊取最大值

4. **Conv2d(16→32, kernel=3, padding=1) → GELU**
   - 輸入: 16×14×14
   - 輸出: 32×14×14
   - 參數計算: 32 × 16 × 3×3 = 4,608

5. **Global Average Pooling (GAP)**
   - 輸入: 32×14×14
   - 輸出: 32×1×1
   - 對每個通道的 14×14 值進行平均

6. **Flatten**
   - 輸入: 32×1×1
   - 輸出: 32 (一維向量)

7. **FC(32→10) → Softmax**
   - 輸入: 32
   - 輸出: 10 (10 個類別的機率分佈)

## 模組說明

### 已實作模組

#### 1. `conv2d_layer1.v`

- **功能**: 第一個卷積層（1→8 通道）
- **特性**:
  - 支援 padding=1
  - 使用 ReLU 激活函數
  - 量化位移參數可調整（QUANT_SHIFT，建議範圍 8~12）
  - 使用 line buffer 和 window generator 實現流式處理
  - 包含 8 個並行的 MAC 單元
- **輸入**: 8-bit 像素資料（串流）
- **輸出**: 8 個通道的 8-bit 卷積結果

#### 2. `line_buffer.v`

- **功能**: 行緩衝器，用於生成 3×3 卷積窗口所需的三行資料
- **特性**:
  - 支援可配置的影像寬度和 padding
  - 自動處理邊界填充（零填充）

#### 3. `window_generator.v`

- **功能**: 窗口生成器，從行緩衝器輸出生成 3×3 卷積窗口
- **特性**:
  - 使用移位暫存器實現滑動窗口
  - 輸出 9 個像素值（win00~win22）

#### 4. `mac_3x3.v`

- **功能**: 3×3 乘加運算單元（Multiply-Accumulate）
- **特性**:
  - 執行 3×3 卷積核與窗口的乘加運算
  - 輸出 32-bit 有符號累加結果

#### 5. `max_pool_unit.v`

- **功能**: 最大池化單元（2×2）
- **特性**:
  - 支援可配置的影像尺寸
  - 實現 2×2 最大池化，輸出尺寸減半
  - 使用行緩衝器優化記憶體使用

#### 6. `global_avg_pool_unit.v`

- **功能**: 全域平均池化單元
- **特性**:
  - 對每個通道的所有像素進行平均
  - 使用近似除法（乘以 167 後右移 15 位）實現高效運算
  - 支援可配置的影像尺寸（預設 14×14）

#### 7. `fc_softmax_unit.v`

- **功能**: 全連接層與 Softmax 單元
- **特性**:
  - 實現 32→10 的全連接層
  - 包含 Softmax 的 argmax 近似（找最大值索引）
  - 從檔案讀取權重和偏置值
  - 輸出最終分類結果（0-9）

#### 8. `conv2d_test.v`

- **功能**: 卷積層測試模組（狀態機版本）
- **特性**:
  - 使用狀態機實現卷積運算
  - 支援權重檔案讀取
  - 可用於驗證卷積運算正確性

### 測試平台

#### `conv2d_layer1_tb.v`

- **功能**: 第一個卷積層的測試平台
- **特性**:
  - 使用 4×4 測試影像
  - 包含完整的時序測試
  - 支援權重覆寫功能

## 激活函數

### ReLU

```
ReLU(x) = max(0, x)
```

### SELU

```
SELU(x) = { λx        if x > 0
          { λα(e^x - 1) if x ≤ 0
```
其中 λ ≈ 1.0507, α ≈ 1.6733

### GELU

```
GELU(x) = xΦ(x) = (1/2)x(1 + erf(x/√2))
```
近似式：
```
GELU(x) ≈ (1/2)x [1 + tanh(√(2/π) (x + 0.044715x³))]
```

### Softmax

```
p_i = exp(z_i - m) / Σ_j exp(z_j - m)
```

其中 `m = max{z_1, z_2, ..., z_k}` (k 是類別數)

## 目前實作進度

### ✅ 已完成

1. **基礎模組**
   - [x] Line Buffer（行緩衝器）
   - [x] Window Generator（窗口生成器）
   - [x] MAC 3×3（乘加運算單元）

2. **第一層卷積（Conv2d Layer 1）**
   - [x] Conv2d(1→8) 模組實作
   - [x] ReLU 激活函數整合
   - [x] 量化與飽和處理
   - [x] 測試平台（conv2d_layer1_tb.v）

3. **池化層**
   - [x] Max Pooling 單元（2×2）
   - [x] Global Average Pooling 單元

4. **全連接層**
   - [x] FC(32→10) 模組
   - [x] Softmax（argmax 近似）實作

### 🚧 進行中 / 待完成

1. **第二層卷積（Conv2d Layer 2）**
   - [ ] Conv2d(8→16) 模組實作
   - [ ] SELU 激活函數實作與整合
   - [ ] 多通道輸入處理（8 通道）

2. **第三層卷積（Conv2d Layer 3）**
   - [ ] Conv2d(16→32) 模組實作
   - [ ] GELU 激活函數實作與整合
   - [ ] 多通道輸入處理（16 通道）

3. **系統整合**
   - [ ] 完整 CNN 頂層模組整合
   - [ ] 層間資料流連接
   - [ ] 時序同步與控制信號

4. **權重檔案**
   - [ ] 準備所有層的量化權重檔案
   - [ ] 權重格式轉換工具

5. **測試與驗證**
   - [ ] 完整系統測試平台
   - [ ] MNIST 測試集驗證
   - [ ] 準確率評估

6. **優化**
   - [ ] 時序優化
   - [ ] 資源使用優化
   - [ ] 功耗優化

## 檔案結構

```
CA_final/
├── README.md                    # 本檔案
├── conv2d_layer1.v              # 第一層卷積（1→8, ReLU）
├── conv2d_layer1_tb.v           # 第一層卷積測試平台
├── conv2d_test.v                # 卷積層測試模組（狀態機版本）
├── fc_softmax_unit.v            # 全連接層與 Softmax
├── global_avg_pool_unit.v       # 全域平均池化單元
├── line_buffer.v                # 行緩衝器
├── mac_3x3.v                    # 3×3 乘加運算單元
├── max_pool_unit.v              # 最大池化單元
└── window_generator.v           # 窗口生成器
```

## 使用說明

### 編譯與模擬

```bash
# 編譯第一層卷積測試
iverilog -o conv2d_layer1_tb conv2d_layer1_tb.v conv2d_layer1.v line_buffer.v window_generator.v mac_3x3.v

# 執行模擬
vvp conv2d_layer1_tb
```

### 權重檔案

- `conv1_relu.txt`: 第一層卷積權重（十六進位格式）
- `weights.txt`: 全連接層權重
- `biases.txt`: 全連接層偏置

## 技術細節

### 量化策略

- 使用固定點量化，權重和激活值均為 8-bit
- 支援可配置的量化位移（QUANT_SHIFT）
- 輸出使用飽和運算限制在 0-255 範圍

### 流水線設計

- Line Buffer: 1 週期延遲
- Window Generator: 1 週期延遲
- MAC: 1 週期延遲
- 總延遲: 約 4 個時脈週期

### 記憶體使用

- Line Buffer 使用兩個行緩衝器（buf1, buf2）
- 權重儲存在記憶體陣列中，使用 `$readmemh` 初始化

## 參考資料

- V. Dumoulin and F. Visin, "A guide to convolution arithmetic for deep learning," arXiv: 1603.07285, 2016. [Online]. Available: https://arxiv.org/abs/1603.07285. doi:10.48550/arXiv.1603.07285
- MNIST 資料集: http://yann.lecun.com/exdb/mnist/

## 授權

本專案為學術研究用途。


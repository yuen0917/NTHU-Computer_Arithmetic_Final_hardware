module conv2d_test #(
    parameter IMG_WIDTH     = 28,
    parameter IMG_HEIGHT    = 28,
    parameter IN_CHANNEL    = 1,
    parameter OUT_CHANNEL   = 8,
    parameter KERNEL_WIDTH  = 3,
    parameter KERNEL_HEIGHT = 3,
    parameter STRIDE        = 1,
    parameter PADDING       = 1
)(
    input                clk,
    input                rst_n,
    input                in_valid,
    input         [ 7:0] in_data,
    output reg           out_valid,
    output reg    [31:0] out_data
);
    localparam IN_SIZE           = IMG_WIDTH*IMG_HEIGHT*IN_CHANNEL;
    localparam OUT_SIZE          = IMG_WIDTH*IMG_HEIGHT*OUT_CHANNEL;
    localparam WEIGHT_SIZE       = OUT_CHANNEL*IN_CHANNEL*KERNEL_WIDTH*KERNEL_HEIGHT;
    localparam X_IDX_WIDTH       = $clog2(IMG_WIDTH);
    localparam Y_IDX_WIDTH       = $clog2(IMG_HEIGHT);
    localparam I_CH_IDX_WIDTH    = $clog2(IN_CHANNEL);
    localparam O_CH_IDX_WIDTH    = $clog2(OUT_CHANNEL);
    localparam KW_WIDTH          = $clog2(KERNEL_WIDTH);
    localparam KH_WIDTH          = $clog2(KERNEL_HEIGHT);
    localparam IN_ADDR_WIDTH     = $clog2(IN_SIZE);
    localparam OUT_ADDR_WIDTH    = $clog2(OUT_SIZE);
    localparam WEIGHT_ADDR_WIDTH = $clog2(WEIGHT_SIZE);

    localparam S_IDLE  = 0;
    localparam S_LOAD  = 1;
    localparam S_INIT  = 2;
    localparam S_MAC   = 3; // Multiply and Accumulate
    localparam S_WRITE = 4;
    localparam S_NEXT  = 5;


    reg signed [7:0] in_data_reg  [0:IN_SIZE-1];
    reg signed [7:0] weight_data  [0:WEIGHT_SIZE-1];

    reg [IN_ADDR_WIDTH-1:0]     in_data_addr;
    reg [X_IDX_WIDTH-1:0]       x_cnt;
    reg [Y_IDX_WIDTH-1:0]       y_cnt;
    reg [I_CH_IDX_WIDTH-1:0]    chi_cnt;
    reg [O_CH_IDX_WIDTH-1:0]    cho_cnt;
    reg [KW_WIDTH-1:0]          kw_cnt;
    reg [KH_WIDTH-1:0]          kh_cnt;
    reg [WEIGHT_ADDR_WIDTH-1:0] w_idx;

    reg signed [31:0] mac_acc;

    reg [3:0] state;
    reg [3:0] next_state;

    // Combinational logic for index calculation
    wire signed [IN_ADDR_WIDTH-1:0] in_idx_comb;
    wire signed [WEIGHT_ADDR_WIDTH-1:0] w_idx_comb;
    wire signed [X_IDX_WIDTH-1:0] x_base_comb;
    wire signed [Y_IDX_WIDTH-1:0] y_base_comb;
    wire valid_pos;

    assign x_base_comb = (x_cnt * STRIDE) + kw_cnt - PADDING;
    assign y_base_comb = (y_cnt * STRIDE) + kh_cnt - PADDING;
    assign valid_pos   = (x_base_comb >= 0 && x_base_comb < IMG_WIDTH && y_base_comb >= 0 && y_base_comb < IMG_HEIGHT);
    assign in_idx_comb = valid_pos ? ((chi_cnt * IMG_HEIGHT) + y_base_comb) * IMG_WIDTH + x_base_comb : 0;
    assign w_idx_comb  = valid_pos ? ((((cho_cnt * IN_CHANNEL) + chi_cnt) * KERNEL_HEIGHT) + kh_cnt) * KERNEL_WIDTH + kw_cnt : 0;

    initial begin
        $readmemh("weights/mnist_weights.hex", weight_data);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            S_IDLE:  next_state = (in_valid) ? S_LOAD : S_IDLE;
            S_LOAD:  next_state = (in_data_addr == IN_SIZE - 1) ? S_INIT : S_LOAD;
            S_INIT:  next_state = S_MAC;
            S_MAC:   next_state = (kw_cnt == KERNEL_WIDTH-1 && kh_cnt == KERNEL_HEIGHT-1 && chi_cnt == IN_CHANNEL-1) ? S_WRITE : S_MAC;
            S_WRITE: next_state = S_NEXT;
            S_NEXT:  next_state = (x_cnt == IMG_WIDTH - 1 && y_cnt == IMG_HEIGHT - 1 && cho_cnt == OUT_CHANNEL - 1) ? S_IDLE : S_MAC;
            default: next_state = S_IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_data_addr  <= 0;
            x_cnt         <= 0;
            y_cnt         <= 0;
            chi_cnt       <= 0;
            cho_cnt       <= 0;
            kw_cnt        <= 0;
            kh_cnt        <= 0;
            mac_acc       <= 0;
            out_valid     <= 0;
            out_data      <= 0;
        end else begin
            case(state)
                S_IDLE: begin
                    if(in_valid) begin
                        in_data_addr <= 0;
                        x_cnt        <= 0;
                        y_cnt        <= 0;
                        cho_cnt      <= 0;
                        out_valid    <= 0;
                        mac_acc      <= 0;
                    end
                end
                S_LOAD: begin
                    if (in_data_addr == IN_SIZE - 1) begin
                        in_data_reg[in_data_addr] <= in_data;
                        in_data_addr              <= 0;
                    end else begin
                        in_data_reg[in_data_addr] <= in_data;
                        in_data_addr              <= in_data_addr + 1;
                    end
                end
                S_INIT: begin
                    x_base   <= 0;
                    y_base   <= 0;
                    chi_cnt  <= 0;
                    kw_cnt   <= 0;
                    kh_cnt   <= 0;
                end
                S_MAC: begin // Multiply and Accumulate one element of the output feature map
                    if (valid_pos) begin
                        mac_acc <= mac_acc + $signed(in_data_reg[in_idx_comb]) * $signed(weight_data[w_idx_comb]);
                    end

                    if (kw_cnt == KERNEL_WIDTH-1) begin
                        kw_cnt <= 0;
                        if (kh_cnt == KERNEL_HEIGHT-1) begin
                            kh_cnt <= 0;
                            if (chi_cnt == IN_CHANNEL-1) begin
                                chi_cnt <= 0;
                            end else begin
                                chi_cnt <= chi_cnt + 1;
                            end
                        end else begin
                            kh_cnt <= kh_cnt + 1;
                        end
                    end else begin
                        kw_cnt <= kw_cnt + 1;
                    end
                end
                S_WRITE: begin
                    out_data <= mac_acc;
                    out_valid <= 1;
                    mac_acc <= 0;
                end
                S_NEXT: begin
                    out_valid <= 0;
                    if (x_cnt == IMG_WIDTH - 1) begin
                        x_cnt <= 0;
                        if (y_cnt == IMG_HEIGHT - 1) begin
                            y_cnt <= 0;
                            if (cho_cnt == OUT_CHANNEL - 1) begin
                                cho_cnt <= 0;
                            end else begin
                                cho_cnt <= cho_cnt + 1;
                            end
                        end else begin
                            y_cnt <= y_cnt + 1;
                        end
                    end else begin
                        x_cnt <= x_cnt + 1;
                    end
                end
                default: begin
                    in_data_addr  <= 0;
                    x_cnt         <= 0;
                    y_cnt         <= 0;
                    chi_cnt       <= 0;
                    cho_cnt       <= 0;
                    kw_cnt        <= 0;
                    kh_cnt        <= 0;
                    mac_acc       <= 0;
                    out_valid     <= 0;
                    out_data      <= 0;
                end
            endcase
        end
    end
endmodule
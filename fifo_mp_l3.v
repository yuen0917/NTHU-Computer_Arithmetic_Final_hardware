`timescale 1ns/1ps

// ============================================================
// FIFO Buffer between MP and L3
// ============================================================
module fifo_mp_l3 #(
    parameter DATA_WIDTH = 8,
    parameter CHANNELS = 16,
    parameter DEPTH = 256,
    parameter IMAGE_SIZE = 3136
)(
    input clk,
    input rst_n,

    input wr_en,
    input [DATA_WIDTH-1:0] wr_data0,  wr_data1,  wr_data2,  wr_data3,
    input [DATA_WIDTH-1:0] wr_data4,  wr_data5,  wr_data6,  wr_data7,
    input [DATA_WIDTH-1:0] wr_data8,  wr_data9,  wr_data10, wr_data11,
    input [DATA_WIDTH-1:0] wr_data12, wr_data13, wr_data14, wr_data15,

    input rd_en,
    output reg [DATA_WIDTH-1:0] rd_data0, rd_data1, rd_data2, rd_data3,
    output reg [DATA_WIDTH-1:0] rd_data4, rd_data5, rd_data6, rd_data7,
    output reg [DATA_WIDTH-1:0] rd_data8, rd_data9, rd_data10, rd_data11,
    output reg [DATA_WIDTH-1:0] rd_data12, rd_data13, rd_data14, rd_data15,
    output reg rd_valid,

    output reg empty,
    output reg full,
    output reg [7:0] count,
    output batch_ready,
    output last_batch
);

    reg [DATA_WIDTH-1:0] mem0 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem1 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem2 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem3 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem4 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem5 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem6 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem7 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem8 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem9 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem10 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem11 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem12 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem13 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem14 [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem15 [0:DEPTH-1];

    reg [7:0] wr_ptr;
    reg [7:0] rd_ptr;

    localparam BATCH_SIZE = 28;
    localparam TOTAL_PIXELS = 196;
    reg [7:0] pixel_cnt;
    reg [2:0] batch_cnt;

    wire wr_allow = wr_en && !full;
    wire rd_allow = rd_en && !empty;

    assign batch_ready = (pixel_cnt >= BATCH_SIZE);

    assign last_batch = (pixel_cnt >= TOTAL_PIXELS);

    reg batch_ready_d;
    always @(posedge clk) batch_ready_d <= batch_ready;

    // DEBUG: Track FIFO operations and data flow
    // always @(posedge clk) begin
    //     if (wr_en && !wr_allow) begin
    //         $display("[MP→FIFO] WRITE BLOCKED: wr_en=1 but full=%d, count=%d", full, count);
    //     end
    //     if (wr_allow && (pixel_cnt < 3 || pixel_cnt >= TOTAL_PIXELS - 3 ||
    //                      (pixel_cnt % BATCH_SIZE == 0) || last_batch)) begin
    //         $display("[MP→FIFO] WRITE: wr_ptr=%d, count=%d, pixel_cnt=%d/%d, batch=%d/7, batch_ready=%d, last_batch=%d, data[0]=%d",
    //                  wr_ptr, count, pixel_cnt, TOTAL_PIXELS, batch_cnt, batch_ready, last_batch, wr_data0);
    //     end

    //     if (rd_allow) begin
    //         $display("[FIFO→L3] READ: rd_ptr=%d, count=%d, pixel_cnt=%d, batch_ready=%d, last_batch=%d, rd_en=%d, data[0]=%d",
    //                  rd_ptr, count, pixel_cnt, batch_ready, last_batch, rd_en, rd_data0);
    //     end
    //     if (rd_en && !batch_ready && !last_batch) begin
    //         $display("[FIFO→L3] READ BLOCKED: rd_en=1 but batch_ready=0, pixel_cnt=%d/%d",
    //                  pixel_cnt, BATCH_SIZE);
    //     end
    //     if (rd_en && empty) begin
    //         $display("[FIFO→L3] READ BLOCKED: rd_en=1 but empty=1, count=%d", count);
    //     end

    //     if (batch_ready && !batch_ready_d) begin
    //         $display("[FIFO] BATCH READY: pixel_cnt=%d, batch_cnt=%d, count=%d", pixel_cnt, batch_cnt, count);
    //     end
    //     if (last_batch && pixel_cnt == TOTAL_PIXELS) begin
    //         $display("[FIFO] LAST BATCH: pixel_cnt=%d, batch_cnt=%d", pixel_cnt, batch_cnt);
    //     end
    // end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
            empty <= 1;
            full <= 0;
            rd_valid <= 0;
            rd_data0 <= 0; rd_data1 <= 0; rd_data2 <= 0; rd_data3 <= 0;
            rd_data4 <= 0; rd_data5 <= 0; rd_data6 <= 0; rd_data7 <= 0;
            rd_data8 <= 0; rd_data9 <= 0; rd_data10 <= 0; rd_data11 <= 0;
            rd_data12 <= 0; rd_data13 <= 0; rd_data14 <= 0; rd_data15 <= 0;
            pixel_cnt <= 0;
            batch_cnt <= 0;
        end else begin
            if (wr_allow) begin
                if (pixel_cnt >= TOTAL_PIXELS) begin
                    pixel_cnt <= TOTAL_PIXELS;
                end else begin
                    pixel_cnt <= pixel_cnt + 1;
                    if ((pixel_cnt + 1) % BATCH_SIZE == 0) begin
                        batch_cnt <= batch_cnt + 1;
                    end
                end
            end
            if (rd_allow && last_batch && count == 1) begin
                pixel_cnt <= 0;
                batch_cnt <= 0;
            end
            if (wr_allow && !rd_allow) begin
                count <= count + 1;
                empty <= 0;
                if ((count + 1) == DEPTH) begin
                    full <= 1;
                end else begin
                    full <= 0;
                end
            end else if (!wr_allow && rd_allow) begin
                count <= count - 1;
                full <= 0;
                if ((count - 1) == 0) begin
                    empty <= 1;
                end else begin
                    empty <= 0;
                end
            end else if (wr_allow && rd_allow) begin
                if (count == 0) begin
                    empty <= 0;
                end
            end

            if (wr_allow) begin
                mem0[wr_ptr]  <= wr_data0;
                mem1[wr_ptr]  <= wr_data1;
                mem2[wr_ptr]  <= wr_data2;
                mem3[wr_ptr]  <= wr_data3;
                mem4[wr_ptr]  <= wr_data4;
                mem5[wr_ptr]  <= wr_data5;
                mem6[wr_ptr]  <= wr_data6;
                mem7[wr_ptr]  <= wr_data7;
                mem8[wr_ptr]  <= wr_data8;
                mem9[wr_ptr]  <= wr_data9;
                mem10[wr_ptr] <= wr_data10;
                mem11[wr_ptr] <= wr_data11;
                mem12[wr_ptr] <= wr_data12;
                mem13[wr_ptr] <= wr_data13;
                mem14[wr_ptr] <= wr_data14;
                mem15[wr_ptr] <= wr_data15;
                wr_ptr <= (wr_ptr == DEPTH - 1) ? 0 : wr_ptr + 1;
            end

            if (rd_allow) begin
                rd_data0  <= mem0[rd_ptr];
                rd_data1  <= mem1[rd_ptr];
                rd_data2  <= mem2[rd_ptr];
                rd_data3  <= mem3[rd_ptr];
                rd_data4  <= mem4[rd_ptr];
                rd_data5  <= mem5[rd_ptr];
                rd_data6  <= mem6[rd_ptr];
                rd_data7  <= mem7[rd_ptr];
                rd_data8  <= mem8[rd_ptr];
                rd_data9  <= mem9[rd_ptr];
                rd_data10 <= mem10[rd_ptr];
                rd_data11 <= mem11[rd_ptr];
                rd_data12 <= mem12[rd_ptr];
                rd_data13 <= mem13[rd_ptr];
                rd_data14 <= mem14[rd_ptr];
                rd_data15 <= mem15[rd_ptr];
                rd_ptr <= (rd_ptr == DEPTH - 1) ? 0 : rd_ptr + 1;
                rd_valid <= 1;
            end else begin
                rd_valid <= 0;
            end
        end
    end

endmodule


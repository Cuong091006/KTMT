`timescale 1ns/1ps

//=============================================================================
// Module:      dummy_ram
// Dự án:       Thiết kế & Mô phỏng DMA Controller (Verilog)
// Vai trò:     Thành viên 4 (Kiểm thử - Testbench & Verification)
// Đối tượng:   Mô hình bộ nhớ RAM giả lập (Dummy RAM Model)
// Mô tả:       Mô phỏng bộ nhớ hệ thống (System Memory) mà DMA controller
//              sẽ trực tiếp đọc dữ liệu nguồn và ghi dữ liệu đích.
//              Có hỗ trợ cấu hình độ trễ (latency) và cờ mem_ready.
//=============================================================================

module dummy_ram #(
    parameter ADDR_WIDTH    = 32,    // Độ rộng bus địa chỉ
    parameter DATA_WIDTH    = 32,    // Độ rộng bus dữ liệu
    parameter MEM_DEPTH     = 1024,  // Số từ nhớ (1024 từ x 4 byte = 4KB RAM)
    parameter READ_LATENCY  = 1,     // Số chu kỳ trễ khi đọc (mô phỏng RAM thực)
    parameter WRITE_LATENCY = 1      // Số chu kỳ trễ khi ghi
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Giao tiếp Bus Bộ nhớ (Khớp chính xác với Master Interface của dma_controller)
    input  wire [ADDR_WIDTH-1:0] mem_addr,
    input  wire                  mem_wr_en,
    input  wire                  mem_rd_en,
    input  wire [DATA_WIDTH-1:0] mem_wr_data,
    output reg  [DATA_WIDTH-1:0] mem_rd_data,
    output reg                   mem_ready
);

    //-------------------------------------------------------------------------
    // Mảng bộ nhớ nội bộ (Internal Memory Array)
    //-------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] mem_array [0:MEM_DEPTH-1];

    // Chỉ số truy cập theo từ (Word-aligned: bỏ 2 bit thấp vì mỗi từ 32-bit = 4 byte)
    wire [$clog2(MEM_DEPTH)-1:0] word_addr;
    assign word_addr = mem_addr[$clog2(MEM_DEPTH)+1:2];

    // Bộ đếm chu kỳ trễ
    reg [3:0] latency_cnt;
    reg       busy;

    //-------------------------------------------------------------------------
    // Logic Đọc / Ghi Bộ nhớ đồng bộ theo Clock
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_rd_data <= {DATA_WIDTH{1'b0}};
            mem_ready   <= 1'b0;
            latency_cnt <= 4'd0;
            busy        <= 1'b0;
        end else begin
            // Mặc định cờ mem_ready chỉ tích cực 1 chu kỳ khi hoàn tất truy xuất
            mem_ready <= 1'b0;

            if (mem_wr_en) begin
                // Chu kỳ ghi dữ liệu
                if (WRITE_LATENCY == 0) begin
                    mem_array[word_addr] <= mem_wr_data;
                    mem_ready            <= 1'b1;
                    $display("[RAM GHI] Dia chi Byte=0x%08h (Word=%0d) | Data=0x%08h @ %0t",
                             mem_addr, word_addr, mem_wr_data, $time);
                end else begin
                    if (!busy) begin
                        busy        <= 1'b1;
                        latency_cnt <= WRITE_LATENCY - 1;
                    end else if (latency_cnt > 0) begin
                        latency_cnt <= latency_cnt - 1;
                    end else begin
                        mem_array[word_addr] <= mem_wr_data;
                        mem_ready            <= 1'b1;
                        busy                 <= 1'b0;
                        $display("[RAM GHI] Dia chi Byte=0x%08h (Word=%0d) | Data=0x%08h @ %0t",
                                 mem_addr, word_addr, mem_wr_data, $time);
                    end
                end
            end else if (mem_rd_en) begin
                // Chu kỳ đọc dữ liệu
                if (READ_LATENCY == 0) begin
                    mem_rd_data <= mem_array[word_addr];
                    mem_ready   <= 1'b1;
                    $display("[RAM DOC] Dia chi Byte=0x%08h (Word=%0d) | Data=0x%08h @ %0t",
                             mem_addr, word_addr, mem_array[word_addr], $time);
                end else begin
                    if (!busy) begin
                        busy        <= 1'b1;
                        latency_cnt <= READ_LATENCY - 1;
                    end else if (latency_cnt > 0) begin
                        latency_cnt <= latency_cnt - 1;
                    end else begin
                        mem_rd_data <= mem_array[word_addr];
                        mem_ready   <= 1'b1;
                        busy        <= 1'b0;
                        $display("[RAM DOC] Dia chi Byte=0x%08h (Word=%0d) | Data=0x%08h @ %0t",
                                 mem_addr, word_addr, mem_array[word_addr], $time);
                    end
                end
            end else begin
                busy        <= 1'b0;
                latency_cnt <= 4'd0;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Task hỗ trợ Testbench: Nạp dữ liệu kiểm thử ban đầu vào RAM
    //-------------------------------------------------------------------------
    task load_pattern;
        input [ADDR_WIDTH-1:0] byte_start_addr;
        input integer          word_count;
        input [DATA_WIDTH-1:0] base_pattern;

        integer i;
        integer start_word;
        begin
            start_word = byte_start_addr[$clog2(MEM_DEPTH)+1:2];
            for (i = 0; i < word_count; i = i + 1) begin
                mem_array[start_word + i] = base_pattern + i;
            end
            $display("[DUMMY_RAM] Da nap %0d tu nho tu dia chi 0x%08h (Base Pattern=0x%08h)",
                     word_count, byte_start_addr, base_pattern);
        end
    endtask

    //-------------------------------------------------------------------------
    // Task hỗ trợ Testbench: In nội dung RAM ra log
    //-------------------------------------------------------------------------
    task dump_memory;
        input [ADDR_WIDTH-1:0] byte_start_addr;
        input integer          word_count;
        input [30*8:1]         region_name;

        integer i;
        integer start_word;
        begin
            start_word = byte_start_addr[$clog2(MEM_DEPTH)+1:2];
            $display("------------------------------------------------------------");
            $display("   DUMP RAM: %s (Tu 0x%08h den 0x%08h)",
                     region_name, byte_start_addr, byte_start_addr + (word_count*4) - 1);
            $display("------------------------------------------------------------");
            for (i = 0; i < word_count; i = i + 1) begin
                $display("   RAM[0x%08h] = 0x%08h",
                         byte_start_addr + (i * 4), mem_array[start_word + i]);
            end
            $display("------------------------------------------------------------");
        end
    endtask

    //-------------------------------------------------------------------------
    // Task hỗ trợ Testbench: So sánh vùng nguồn và vùng đích sau khi DMA truyền
    //-------------------------------------------------------------------------
    task verify_transfer;
        input [ADDR_WIDTH-1:0] src_byte_addr;
        input [ADDR_WIDTH-1:0] dst_byte_addr;
        input integer          word_count;
        output reg             is_match;

        integer i;
        integer src_idx;
        integer dst_idx;
        reg [DATA_WIDTH-1:0] src_val;
        reg [DATA_WIDTH-1:0] dst_val;
        begin
            is_match = 1'b1;
            src_idx = src_byte_addr[$clog2(MEM_DEPTH)+1:2];
            dst_idx = dst_byte_addr[$clog2(MEM_DEPTH)+1:2];

            $display("[DUMMY_RAM] Dang so sanh du lieu: SRC=0x%08h -> DST=0x%08h (%0d tu)",
                     src_byte_addr, dst_byte_addr, word_count);

            for (i = 0; i < word_count; i = i + 1) begin
                src_val = mem_array[src_idx + i];
                dst_val = mem_array[dst_idx + i];
                if (src_val !== dst_val) begin
                    $display("   [SAI LECH] Tai Word %0d: SRC[0x%08h]=0x%08h != DST[0x%08h]=0x%08h",
                             i, src_byte_addr + (i*4), src_val, dst_byte_addr + (i*4), dst_val);
                    is_match = 1'b0;
                end
            end

            if (is_match)
                $display("   [DUNG] Du lieu vung dich khop 100%% voi vung nguon!");
            else
                $display("   [LOI] Phat hien sai lech du lieu trong qua trinh DMA truyen!");
        end
    endtask

endmodule

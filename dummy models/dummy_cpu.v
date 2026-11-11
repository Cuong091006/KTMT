`timescale 1ns/1ps

//=============================================================================
// Module:      dummy_cpu
// Dự án:       Thiết kế & Mô phỏng DMA Controller (Verilog)
// Vai trò:     Thành viên 4 (Kiểm thử - Testbench & Verification)
// Đối tượng:   Mô hình CPU giả lập (Dummy CPU Master Model)
// Mô tả:       Đóng vai trò là bộ vi xử lý (Host CPU) cấu hình DMA controller
//              qua tập thanh ghi (Slave Interface) và lắng nghe tín hiệu ngắt intr.
//=============================================================================

module dummy_cpu (
    input  wire        clk,
    input  wire        rst_n,

    // Giao tiếp Slave Interface của DMA Controller
    output reg  [3:0]  cpu_addr,
    output reg         cpu_wr_en,
    output reg         cpu_rd_en,
    output reg  [31:0] cpu_wr_data,
    input  wire [31:0] cpu_rd_data,
    input  wire        intr
);

    //-------------------------------------------------------------------------
    // Khởi tạo trạng thái ban đầu
    //-------------------------------------------------------------------------
    initial begin
        cpu_addr    = 4'h0;
        cpu_wr_en   = 1'b0;
        cpu_rd_en   = 1'b0;
        cpu_wr_data = 32'h0;
    end

    //-------------------------------------------------------------------------
    // Task: CPU ghi 1 từ vào thanh ghi DMA (1 chu kỳ)
    //-------------------------------------------------------------------------
    task write_reg;
        input [3:0]  reg_offset;
        input [31:0] wdata;
        begin
            @(posedge clk);
            cpu_addr    <= reg_offset;
            cpu_wr_data <= wdata;
            cpu_wr_en   <= 1'b1;
            cpu_rd_en   <= 1'b0;

            @(posedge clk);
            cpu_wr_en   <= 1'b0;
            $display("[DUMMY_CPU GHI] Reg[0x%01h] <= 0x%08h @ %0t", reg_offset, wdata, $time);
        end
    endtask

    //-------------------------------------------------------------------------
    // Task: CPU đọc 1 từ từ thanh ghi DMA
    //-------------------------------------------------------------------------
    task read_reg;
        input  [3:0]  reg_offset;
        output [31:0] rdata;
        begin
            @(posedge clk);
            cpu_addr    <= reg_offset;
            cpu_rd_en   <= 1'b1;
            cpu_wr_en   <= 1'b0;

            @(posedge clk);
            #1; // Đợi giá trị ổn định
            rdata       = cpu_rd_data;
            cpu_rd_en   <= 1'b0;
            $display("[DUMMY_CPU DOC] Reg[0x%01h] => 0x%08h @ %0t", reg_offset, rdata, $time);
        end
    endtask

    //-------------------------------------------------------------------------
    // Task: Cấu hình trọn gói kênh DMA (Nguồn, Đích, Số byte/từ, Chế độ)
    //-------------------------------------------------------------------------
    task config_channel;
        input [31:0] src_addr;
        input [31:0] dst_addr;
        input [31:0] transfer_len;
        input [31:0] ctrl_config;
        begin
            $display("\n[DUMMY_CPU] >>> BAT DAU CAU HINH KENH DMA <<<");
            write_reg(4'h0, src_addr);      // 0x0: Source Address
            write_reg(4'h4, dst_addr);      // 0x4: Destination Address
            write_reg(4'h8, transfer_len);  // 0x8: Transfer Length / Count
            write_reg(4'hC, ctrl_config);   // 0xC: Control & Status Register (Start / Enable)
            $display("[DUMMY_CPU] >>> CAU HINH HOAN TAT <<<\n");
        end
    endtask

    //-------------------------------------------------------------------------
    // Task: CPU chờ tín hiệu ngắt intr (với cơ chế Timeout chống treo)
    //-------------------------------------------------------------------------
    task wait_for_intr;
        input integer timeout_cycles;
        output reg    timed_out;

        integer count;
        begin
            timed_out = 1'b0;
            count = 0;
            $display("[DUMMY_CPU] Dang cho ngat (intr) tu DMA...");

            while (!intr && count < timeout_cycles) begin
                @(posedge clk);
                count = count + 1;
            end

            if (intr) begin
                $display("[DUMMY_CPU] Nhan duoc ngat INTR sau %0d chu ky! @ %0t", count, $time);
            end else begin
                timed_out = 1'b1;
                $display("[DUMMY_CPU] CANH BAO: TIMEOUT! Khong nhan duoc ngat sau %0d chu ky!", timeout_cycles);
            end
        end
    endtask

endmodule

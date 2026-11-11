`timescale 1ns/1ps

//=============================================================================
// Module:      tb_dma_top
// Dự án:       Thiết kế & Mô phỏng DMA Controller (Verilog)
// Vai trò:     Thành viên 4 (Kiểm thử - Testbench & Verification)
// Đối tượng:   Môi trường kiểm thử tích hợp toàn diện mức Hệ Thống (System-level TB)
// Mô tả:       Kết nối đồng bộ:
//              - dma_controller (Top-level RTL)
//              - dummy_ram      (Mô hình RAM giả lập)
//              - dummy_arbiter  (Mô hình Arbiter cấp bus)
//              - Kịch bản CPU   (Giả lập CPU ghi thanh ghi và lắng nghe ngắt)
//              - Kịch bản ngoại vi (Giả lập dreq và dack)
//=============================================================================

module tb_dma_top;

    localparam CLK_PERIOD = 10; // 100MHz

    //-------------------------------------------------------------------------
    // 1. Tín hiệu Hệ Thống
    //-------------------------------------------------------------------------
    reg         clk;
    reg         rst_n;

    // CPU Slave Bus
    reg  [3:0]  cpu_addr;
    reg         cpu_wr_en;
    reg         cpu_rd_en;
    reg  [31:0] cpu_wr_data;
    wire [31:0] cpu_rd_data;
    wire        intr;

    // RAM Master Bus
    wire        bus_req;
    wire        bus_grant;
    wire [31:0] mem_addr;
    wire        mem_wr_en;
    wire        mem_rd_en;
    wire [31:0] mem_wr_data;
    wire [31:0] mem_rd_data;
    wire        mem_ready;

    // Ngoại vi DMA
    reg         dreq;
    wire        dack;

    // Biến quản lý kiểm thử
    integer     test_count;
    integer     pass_count;
    integer     fail_count;
    reg         verify_ok;

    //-------------------------------------------------------------------------
    // 2. Khởi tạo DUT Top-level (dma_controller)
    //-------------------------------------------------------------------------
    dma_controller u_dma_top (
        .clk         (clk),
        .rst_n       (rst_n),
        // CPU Slave Interface
        .cpu_addr    (cpu_addr),
        .cpu_wr_en   (cpu_wr_en),
        .cpu_rd_en   (cpu_rd_en),
        .cpu_wr_data (cpu_wr_data),
        .cpu_rd_data (cpu_rd_data),
        .intr        (intr),
        // Memory Master Interface
        .bus_req     (bus_req),
        .bus_grant   (bus_grant),
        .mem_addr    (mem_addr),
        .mem_wr_en   (mem_wr_en),
        .mem_rd_en   (mem_rd_en),
        .mem_wr_data (mem_wr_data),
        .mem_rd_data (mem_rd_data),
        .mem_ready   (mem_ready),
        // Peripheral Handshake
        .dreq        (dreq),
        .dack        (dack)
    );

    //-------------------------------------------------------------------------
    // 3. Khởi tạo Mô hình RAM Giả lập (dummy_ram)
    //-------------------------------------------------------------------------
    dummy_ram #(
        .ADDR_WIDTH    (32),
        .DATA_WIDTH    (32),
        .MEM_DEPTH     (1024),
        .READ_LATENCY  (1),
        .WRITE_LATENCY (1)
    ) u_dummy_ram (
        .clk         (clk),
        .rst_n       (rst_n),
        .mem_addr    (mem_addr),
        .mem_wr_en   (mem_wr_en),
        .mem_rd_en   (mem_rd_en),
        .mem_wr_data (mem_wr_data),
        .mem_rd_data (mem_rd_data),
        .mem_ready   (mem_ready)
    );

    //-------------------------------------------------------------------------
    // 4. Khởi tạo Mô hình Arbiter Giả lập (dummy_arbiter)
    //-------------------------------------------------------------------------
    dummy_arbiter #(
        .GRANT_DELAY (1) // Cấp bus sau 1 chu kỳ
    ) u_dummy_arbiter (
        .clk       (clk),
        .rst_n     (rst_n),
        .bus_req   (bus_req),
        .bus_grant (bus_grant)
    );

    //-------------------------------------------------------------------------
    // 5. Tạo Xung Nhịp Clock
    //-------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    //-------------------------------------------------------------------------
    // 6. Các Task Điều Khiển CPU (CPU Driver Tasks)
    //-------------------------------------------------------------------------
    task cpu_write;
        input [3:0]  addr;
        input [31:0] data;
        begin
            @(posedge clk);
            cpu_addr    <= addr;
            cpu_wr_data <= data;
            cpu_wr_en   <= 1'b1;
            cpu_rd_en   <= 1'b0;
            @(posedge clk);
            cpu_wr_en   <= 1'b0;
        end
    endtask

    task cpu_read;
        input  [3:0]  addr;
        output [31:0] data;
        begin
            @(posedge clk);
            cpu_addr    <= addr;
            cpu_rd_en   <= 1'b1;
            cpu_wr_en   <= 1'b0;
            @(posedge clk);
            #1;
            data        = cpu_rd_data;
            cpu_rd_en   <= 1'b0;
        end
    endtask

    task wait_for_interrupt;
        input integer max_cycles;
        output reg    ok;
        integer i;
        begin
            ok = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                @(posedge clk);
                if (intr) begin
                    ok = 1'b1;
                    $display("[TESTBENCH] Nhan duoc tin hieu ngat INTR sau %0d chu ky!", i);
                    disable wait_for_interrupt;
                end
            end
            $display("[TESTBENCH] LOI TIMEOUT: Khong nhan duoc INTR sau %0d chu ky!", max_cycles);
        end
    endtask

    //-------------------------------------------------------------------------
    // 7. Quy Trình Kiểm Thử Hệ Thống (System Verification Sequence)
    //-------------------------------------------------------------------------
    reg [31:0] rdata_tmp;
    reg        intr_ok;

    initial begin
        $dumpfile("dma_top_wave.vcd");
        $dumpvars(0, tb_dma_top);

        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        rst_n       = 1'b0;
        cpu_addr    = 4'h0;
        cpu_wr_en   = 1'b0;
        cpu_rd_en   = 1'b0;
        cpu_wr_data = 32'h0;
        dreq        = 1'b0;

        $display("\n===============================================================================");
        $display("   TESTBENCH HE THONG: DMA CONTROLLER INTEGRATION VERIFICATION");
        $display("   Thanh vien: 4 (Verification Lead)");
        $display("===============================================================================\n");

        // 1. Reset hệ thống
        #(CLK_PERIOD * 3);
        rst_n = 1'b1;
        #(CLK_PERIOD * 2);

        //---------------------------------------------------------------------
        // TEST 1: Kiem tra Doc / Ghi thanh ghi cau hinh CPU
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- TEST %0d: Kiem tra tap thanh ghi cau hinh (Register R/W) ---", test_count);
        cpu_write(4'h0, 32'h1000_0000); // Ghi SRC
        cpu_write(4'h4, 32'h2000_0000); // Ghi DST
        cpu_write(4'h8, 32'h0000_0004); // Ghi LEN = 4

        cpu_read(4'h0, rdata_tmp);
        if (rdata_tmp === 32'h1000_0000) begin
            $display("[PASS] Doc thanh ghi SRC khop: 0x%08h", rdata_tmp);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Doc thanh ghi SRC sai! Mong doi: 0x10000000, Thuc te: 0x%08h", rdata_tmp);
            fail_count = fail_count + 1;
        end

        //---------------------------------------------------------------------
        // TEST 2: Truyen DMA don gian (Single Transfer - 1 Word 32-bit)
        // Nguon: 0x0000_0010 (Word 4) -> Dich: 0x0000_0080 (Word 32)
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- TEST %0d: Truyen DMA 1 Word (Single Word Transfer) ---", test_count);

        // Nạp dữ liệu mẫu vào RAM nguồn
        u_dummy_ram.load_pattern(32'h0000_0010, 1, 32'hCAFE_0001);

        // CPU cấu hình DMA
        cpu_write(4'h0, 32'h0000_0010); // SRC = 0x10
        cpu_write(4'h4, 32'h0000_0080); // DST = 0x80
        cpu_write(4'h8, 32'h0000_0001); // LEN = 1 Word
        cpu_write(4'hC, 32'h0000_0003); // Enable DMA (bit 0=1) & Enable IRQ (bit 1=1)

        // Ngoại vi kích hoạt dreq
        @(posedge clk);
        dreq <= 1'b1;

        // Đợi ngắt từ DMA
        wait_for_interrupt(200, intr_ok);

        // Ngoại vi nhận dack thì hạ dreq
        if (dack) @(posedge clk) dreq <= 1'b0;

        // So sánh kiểm tra kết quả trong RAM
        u_dummy_ram.verify_transfer(32'h0000_0010, 32'h0000_0080, 1, verify_ok);

        if (intr_ok && verify_ok) begin
            $display("[PASS] TEST %0d THANH CONG: Truyen 1 word chinh xac & nhan ngat intr!", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TEST %0d THAT BAI!", test_count);
            fail_count = fail_count + 1;
        end

        // CPU xóa cờ ngắt bằng cách ghi bit 3 vào Control reg (W1C)
        cpu_write(4'hC, 32'h0000_0008);
        #20;

        //---------------------------------------------------------------------
        // TEST 3: Truyen Burst DMA (Burst Transfer - 8 Words)
        // Nguon: 0x0000_0100 -> Dich: 0x0000_0200
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- TEST %0d: Truyen Burst DMA 8 Words (Block Transfer) ---", test_count);

        // Nạp 8 từ dữ liệu mẫu liên tiếp
        u_dummy_ram.load_pattern(32'h0000_0100, 8, 32'h55AA_0000);

        // CPU cấu hình DMA
        cpu_write(4'h0, 32'h0000_0100); // SRC
        cpu_write(4'h4, 32'h0000_0200); // DST
        cpu_write(4'h8, 32'h0000_0008); // LEN = 8 Words
        cpu_write(4'hC, 32'h0000_0003); // Enable DMA & IRQ

        // Kích hoạt dreq
        @(posedge clk);
        dreq <= 1'b1;

        // Chờ ngắt
        wait_for_interrupt(500, intr_ok);

        if (dack) @(posedge clk) dreq <= 1'b0;

        // Hiển thị nội dung bộ nhớ vùng đích để kiểm tra trực quan
        u_dummy_ram.dump_memory(32'h0000_0200, 8, "Vung Dich Sau Khi Truyen Burst");

        // So sánh tự động
        u_dummy_ram.verify_transfer(32'h0000_0100, 32'h0000_0200, 8, verify_ok);

        if (intr_ok && verify_ok) begin
            $display("[PASS] TEST %0d THANH CONG: Truyen burst 8 words toan ven!", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TEST %0d THAT BAI!", test_count);
            fail_count = fail_count + 1;
        end

        // Xóa cờ ngắt
        cpu_write(4'hC, 32'h0000_0008);

        //---------------------------------------------------------------------
        // TỔNG KẾT TOÀN DIỆN MÔ PHỎNG
        //---------------------------------------------------------------------
        $display("\n===============================================================================");
        $display("   KET QUA KIEM THU HE THONG DMA CONTROLLER (tb_dma_top)");
        $display("===============================================================================");
        $display("   Tong so Testcases : %0d", test_count);
        $display("   So Test PASS      : %0d", pass_count);
        $display("   So Test FAIL      : %0d", fail_count);
        $display("===============================================================================");

        if (fail_count == 0) begin
            $display(">>> TUYET VOI! HE THONG DMA DAT 100%% CAC TIEU CHUAN KIEM THU! <<<");
        end else begin
            $display(">>> CANH BAO: CO %0d TESTCASE CHUA DAT! <<<", fail_count);
        end
        $display("===============================================================================\n");

        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule

`timescale 1ns/1ps

//=============================================================================
// Module:      tb_dma_fsm
// Dự án:       Thiết kế & Mô phỏng DMA Controller (Verilog)
// Vai trò:     Thành viên 4 (Kiểm thử - Testbench & Verification)
// Đối tượng:   Kiểm thử đơn vị (Unit Test) cho dma_fsm (TV1 thiết kế)
// Mô tả:       Tự động hóa kiểm tra tất cả các trạng thái, chuyển nhánh,
//              tín hiệu Moore outputs và các trường hợp biên của FSM.
//=============================================================================

module tb_dma_fsm;

    //-------------------------------------------------------------------------
    // 1. Tham số & Định nghĩa hằng số
    //-------------------------------------------------------------------------
    localparam CLK_PERIOD = 10; // Chu kỳ clock = 10ns (Tương ứng tần số 100MHz)

    // Mã hóa trạng thái FSM (khớp với dma_fsm.v của TV1)
    localparam [1:0] FSM_IDLE     = 2'b00;
    localparam [1:0] FSM_REQ_BUS  = 2'b01;
    localparam [1:0] FSM_TRANSFER = 2'b10;
    localparam [1:0] FSM_DONE     = 2'b11;

    //-------------------------------------------------------------------------
    // 2. Tín hiệu kết nối với DUT (Device Under Test)
    //-------------------------------------------------------------------------
    // Inputs đến DUT (Dạng reg để testbench chủ động lái tín hiệu)
    reg        clk;
    reg        rst_n;
    reg        dma_en;
    reg        dreq;
    reg        bus_grant;
    reg        transfer_done;

    // Outputs từ DUT (Dạng wire để hứng dữ liệu)
    wire       dma_done;
    wire       dma_busy;
    wire       bus_req;
    wire       dack;
    wire       start_transfer;

    // Biến thống kê kết quả kiểm thử
    integer    pass_count;
    integer    fail_count;
    integer    test_step;

    // Chuỗi mô tả trạng thái để hiển thị log trực quan
    reg [8*10-1:0] state_str;
    always @(*) begin
        case (uut.state)
            FSM_IDLE:     state_str = "IDLE";
            FSM_REQ_BUS:  state_str = "REQ_BUS";
            FSM_TRANSFER: state_str = "TRANSFER";
            FSM_DONE:     state_str = "DONE";
            default:      state_str = "UNKNOWN";
        endcase
    end

    //-------------------------------------------------------------------------
    // 3. Khởi tạo đối tượng kiểm thử (DUT Instantiation)
    //-------------------------------------------------------------------------
    dma_fsm uut (
        .clk            (clk),
        .rst_n          (rst_n),
        .dma_en         (dma_en),
        .dma_done       (dma_done),
        .dma_busy       (dma_busy),
        .dreq           (dreq),
        .bus_grant      (bus_grant),
        .bus_req        (bus_req),
        .dack           (dack),
        .transfer_done  (transfer_done),
        .start_transfer (start_transfer)
    );

    //-------------------------------------------------------------------------
    // 4. Tạo Xung Nhịp Clock (100MHz)
    //-------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    //-------------------------------------------------------------------------
    // 5. Task hỗ trợ kiểm tra tự động (Self-checking Tasks)
    //-------------------------------------------------------------------------
    task check_fsm;
        input [1:0]  exp_state;
        input        exp_bus_req;
        input        exp_start_transfer;
        input        exp_dack;
        input        exp_dma_done;
        input        exp_dma_busy;
        input [40*8:1] step_name;

        reg is_ok;
        begin
            test_step = test_step + 1;
            is_ok = 1'b1;

            if (uut.state !== exp_state) begin
                $display("[FAIL] Step %02d: %s | Sai State! Mong doi=%0b, Thuc te=%0b (%s) @ %0t",
                         test_step, step_name, exp_state, uut.state, state_str, $time);
                is_ok = 1'b0;
            end
            if (bus_req !== exp_bus_req) begin
                $display("[FAIL] Step %02d: %s | Sai bus_req! Mong doi=%0b, Thuc te=%0b @ %0t",
                         test_step, step_name, exp_bus_req, bus_req, $time);
                is_ok = 1'b0;
            end
            if (start_transfer !== exp_start_transfer) begin
                $display("[FAIL] Step %02d: %s | Sai start_transfer! Mong doi=%0b, Thuc te=%0b @ %0t",
                         test_step, step_name, exp_start_transfer, start_transfer, $time);
                is_ok = 1'b0;
            end
            if (dack !== exp_dack) begin
                $display("[FAIL] Step %02d: %s | Sai dack! Mong doi=%0b, Thuc te=%0b @ %0t",
                         test_step, step_name, exp_dack, dack, $time);
                is_ok = 1'b0;
            end
            if (dma_done !== exp_dma_done) begin
                $display("[FAIL] Step %02d: %s | Sai dma_done! Mong doi=%0b, Thuc te=%0b @ %0t",
                         test_step, step_name, exp_dma_done, dma_done, $time);
                is_ok = 1'b0;
            end
            if (dma_busy !== exp_dma_busy) begin
                $display("[FAIL] Step %02d: %s | Sai dma_busy! Mong doi=%0b, Thuc te=%0b @ %0t",
                         test_step, step_name, exp_dma_busy, dma_busy, $time);
                is_ok = 1'b0;
            end

            if (is_ok) begin
                $display("[PASS] Step %02d: %s | State=%s | bus_req=%b start=%b dack=%b done=%b busy=%b",
                         test_step, step_name, state_str, bus_req, start_transfer, dack, dma_done, dma_busy);
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // 6. Kịch bản kiểm thử chi tiết (Main Test Flow)
    //-------------------------------------------------------------------------
    initial begin
        // Khởi tạo file xuất dạng sóng VCD (mở bằng GTKWave/ModelSim)
        $dumpfile("dma_fsm_wave.vcd");
        $dumpvars(0, tb_dma_fsm);

        // Khởi tạo biến
        pass_count = 0;
        fail_count = 0;
        test_step  = 0;

        rst_n         = 1'b0;
        dma_en        = 1'b0;
        dreq          = 1'b0;
        bus_grant     = 1'b0;
        transfer_done = 1'b0;

        $display("\n===============================================================================");
        $display("   BAT DAU KIEM THU MO-DUN FSM (dma_fsm.v) - VERILOG DMA CONTROLLER");
        $display("   Thuc hien boi: Thanh vien 4 (Verification Lead)");
        $display("===============================================================================\n");

        //---------------------------------------------------------------------
        // TESTCASE 1: Reset Ban Đầu (Power-on Reset)
        //---------------------------------------------------------------------
        #(CLK_PERIOD * 2);
        check_fsm(FSM_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "TC01: Reset tich cuc muc thap (rst_n=0)");

        @(negedge clk);
        rst_n = 1'b1; // Nha reset
        #(CLK_PERIOD);
        check_fsm(FSM_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "TC01b: Sau khi nha reset, duy tri IDLE");

        //---------------------------------------------------------------------
        // TESTCASE 2: Kiem tra giu trang thai IDLE khi chua du dieu kien
        //---------------------------------------------------------------------
        // 2a: Chi co dreq=1, nhung dma_en=0 (CPU chua cho phep)
        @(negedge clk);
        dreq = 1'b1;
        dma_en = 1'b0;
        @(posedge clk);
        #1;
        check_fsm(FSM_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "TC02a: dreq=1 nhung dma_en=0 -> Van o IDLE");

        // 2b: Chi co dma_en=1, nhung dreq=0 (CPU bat san, nhung ngoai vi chua can)
        @(negedge clk);
        dreq = 1'b0;
        dma_en = 1'b1;
        @(posedge clk);
        #1;
        check_fsm(FSM_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "TC02b: dma_en=1 nhung dreq=0 -> Van o IDLE");

        //---------------------------------------------------------------------
        // TESTCASE 3: Kich hoat DMA: Chuyen IDLE -> REQ_BUS
        //---------------------------------------------------------------------
        @(negedge clk);
        dreq   = 1'b1;
        dma_en = 1'b1;
        @(posedge clk);
        #1;
        check_fsm(FSM_REQ_BUS, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, "TC03: Du dreq & dma_en -> Sang REQ_BUS (bus_req=1)");

        //---------------------------------------------------------------------
        // TESTCASE 4: Cho cap Bus trong REQ_BUS (bus_grant=0)
        // FSM phai giu o REQ_BUS va tiep tuc keo bus_req=1
        //---------------------------------------------------------------------
        repeat (4) begin
            @(posedge clk);
            #1;
        end
        check_fsm(FSM_REQ_BUS, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, "TC04: Cho Arbiter cap Bus trong 4 chu ky");

        //---------------------------------------------------------------------
        // TESTCASE 5: Chuyen REQ_BUS -> TRANSFER khi nhan duoc bus_grant
        //---------------------------------------------------------------------
        @(negedge clk);
        bus_grant = 1'b1;
        @(posedge clk);
        #1;
        check_fsm(FSM_TRANSFER, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1, "TC05: Nhan bus_grant=1 -> Sang TRANSFER (start_transfer=1)");

        //---------------------------------------------------------------------
        // TESTCASE 6: Qua trinh truyen du lieu (Dang trong TRANSFER)
        // Tín hiệu bus_req & start_transfer phai duy tri suot qua trinh truyen
        //---------------------------------------------------------------------
        repeat (6) begin
            @(posedge clk);
            #1;
        end
        check_fsm(FSM_TRANSFER, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1, "TC06: Duy tri TRANSFER khi transfer_done=0");

        //---------------------------------------------------------------------
        // TESTCASE 7: Hoan tat truyen: Chuyen TRANSFER -> DONE khi transfer_done=1
        // Kiểm tra xung dma_done=1, dack=1, dma_busy=1, bus_req=0
        //---------------------------------------------------------------------
        @(negedge clk);
        transfer_done = 1'b1;
        @(posedge clk);
        #1;
        check_fsm(FSM_DONE, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, "TC07: transfer_done=1 -> Sang DONE (dack=1, dma_done=1)");

        //---------------------------------------------------------------------
        // TESTCASE 8: Tu dong chuyen DONE -> IDLE sau 1 chu ky clock
        // Sau DONE, tat ca cac tin hieu output phai tro ve 0
        //---------------------------------------------------------------------
        @(negedge clk);
        // Sau khi xong, ngoai vi ha dreq, CPU ha dma_en va datapath ha transfer_done
        dreq          = 1'b0;
        dma_en        = 1'b0;
        bus_grant     = 1'b0;
        transfer_done = 1'b0;

        @(posedge clk);
        #1;
        check_fsm(FSM_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "TC08: Tu dong tro ve IDLE sau 1 chu ky DONE");

        //---------------------------------------------------------------------
        // TESTCASE 9: Truyen lien tiep lan 2 (Back-to-back Transfer)
        // Kiem tra FSM co the tai khoi dong ngay lap tuc ma khong bi ket
        //---------------------------------------------------------------------
        @(negedge clk);
        dreq   = 1'b1;
        dma_en = 1'b1;
        @(posedge clk);
        #1;
        check_fsm(FSM_REQ_BUS, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, "TC09a: Tai kich hoat lan 2 -> Sang REQ_BUS");

        @(negedge clk);
        bus_grant = 1'b1;
        @(posedge clk);
        #1;
        check_fsm(FSM_TRANSFER, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1, "TC09b: Lan 2 vao TRANSFER");

        @(negedge clk);
        transfer_done = 1'b1;
        @(posedge clk);
        #1;
        check_fsm(FSM_DONE, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, "TC09c: Lan 2 vao DONE");

        @(negedge clk);
        dreq          = 1'b0;
        dma_en        = 1'b0;
        bus_grant     = 1'b0;
        transfer_done = 1'b0;
        @(posedge clk);
        #1;
        check_fsm(FSM_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "TC09d: Lan 2 tro ve IDLE thanh cong");

        //---------------------------------------------------------------------
        // TESTCASE 10: Reset ngat bat ngo khi dang giua TRANSFER (Edge Case)
        // Khi dang truyen ma he thong bi reset dot ngot, FSM phai lap tuc ve IDLE
        //---------------------------------------------------------------------
        @(negedge clk);
        dreq      = 1'b1;
        dma_en    = 1'b1;
        bus_grant = 1'b1;
        @(posedge clk);
        @(posedge clk); // Dang o TRANSFER

        // Kich hoat Reset bat ngo giua chu ky
        #3;
        rst_n = 1'b0;
        #1;
        check_fsm(FSM_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "TC10: Reset bat ngo (Async Reset) giua TRANSFER -> ve ngay IDLE");

        @(negedge clk);
        rst_n = 1'b1;
        dreq  = 1'b0;
        dma_en = 1'b0;
        bus_grant = 1'b0;
        #(CLK_PERIOD * 2);
        check_fsm(FSM_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "TC10b: He thong phuc hoi on dinh tai IDLE");

        //---------------------------------------------------------------------
        // BÁO CÁO TỔNG KẾT KIỂM THỬ
        //---------------------------------------------------------------------
        $display("\n===============================================================================");
        $display("   KET QUA TONG KET KIEM THU FSM (dma_fsm.v)");
        $display("===============================================================================");
        $display("   Tong so buoc test (Steps) : %0d", test_step);
        $display("   So buoc PASS              : %0d", pass_count);
        $display("   So buoc FAIL              : %0d", fail_count);
        $display("===============================================================================");

        if (fail_count == 0) begin
            $display(">>> XAC NHAN: MO-DUN dma_fsm CUA TV1 DAT 100%% YEU CAU THIET KE! <<<");
        end else begin
            $display(">>> CANH BAO: CO %0d LOI TRONG FSM CAN TV1 CHINH SUA! <<<", fail_count);
        end
        $display("===============================================================================\n");

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule

`timescale 1ns/1ps

//=============================================================================
// Module:      dummy_peripheral
// Dự án:       Thiết kế & Mô phỏng DMA Controller (Verilog)
// Vai trò:     Thành viên 4 (Kiểm thử - Testbench & Verification)
// Đối tượng:   Mô hình thiết bị ngoại vi giả lập (Dummy Peripheral Model)
// Mô tả:       Mô phỏng thiết bị I/O (Card mạng, Ổ đĩa, ADC, UART, v.v.)
//              phát tín hiệu dreq yêu cầu truyền dữ liệu qua DMA,
//              và đợi phản hồi dack từ DMA controller khi hoàn thành.
//=============================================================================

module dummy_peripheral (
    input  wire clk,
    input  wire rst_n,

    // Giao tiếp với DMA Controller
    output reg  dreq,
    input  wire dack
);

    initial begin
        dreq = 1'b0;
    end

    //-------------------------------------------------------------------------
    // Task: Ngoại vi phát tín hiệu yêu cầu DMA (dreq = 1)
    //-------------------------------------------------------------------------
    task request_transfer;
        begin
            @(posedge clk);
            dreq <= 1'b1;
            $display("[DUMMY_PERIPHERAL] Ngoai vi phat yeu cau truyen DMA (dreq=1) @ %0t", $time);
        end
    endtask

    //-------------------------------------------------------------------------
    // Task: Ngoại vi chờ tín hiệu xác nhận hoàn thành dack từ DMA
    //-------------------------------------------------------------------------
    task wait_for_ack;
        input integer timeout_cycles;
        output reg    timed_out;

        integer count;
        begin
            timed_out = 1'b0;
            count = 0;
            $display("[DUMMY_PERIPHERAL] Ngoai vi dang cho dack tu DMA...");

            while (!dack && count < timeout_cycles) begin
                @(posedge clk);
                count = count + 1;
            end

            if (dack) begin
                $display("[DUMMY_PERIPHERAL] Nhan duoc dack tu DMA sau %0d chu ky! @ %0t", count, $time);
                @(posedge clk);
                dreq <= 1'b0; // Ha yeu cau sau khi da nhan duoc phuc vu
            end else begin
                timed_out = 1'b1;
                $display("[DUMMY_PERIPHERAL] CANH BAO: TIMEOUT cho dack!");
            end
        end
    endtask

endmodule

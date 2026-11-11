`timescale 1ns/1ps

//=============================================================================
// Module:      dummy_arbiter
// Dự án:       Thiết kế & Mô phỏng DMA Controller (Verilog)
// Vai trò:     Thành viên 4 (Kiểm thử - Testbench & Verification)
// Đối tượng:   Mô hình bộ phân xử Bus giả lập (Dummy Bus Arbiter)
// Mô tả:       Phân xử quyền chiếm bus giữa CPU và DMA.
//              Khi DMA kéo bus_req lên 1, Arbiter sẽ cấp bus_grant sau GRANT_DELAY chu kỳ.
//              Khi DMA hạ bus_req về 0, Arbiter lập tức thu hồi bus_grant.
//=============================================================================

module dummy_arbiter #(
    parameter GRANT_DELAY = 1  // Số chu kỳ delay trước khi cấp bus cho DMA
)(
    input  wire clk,
    input  wire rst_n,

    // Tín hiệu giao tiếp với DMA Controller
    input  wire bus_req,
    output reg  bus_grant
);

    reg [3:0] delay_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_grant <= 1'b0;
            delay_cnt <= 4'd0;
        end else begin
            if (bus_req) begin
                if (GRANT_DELAY == 0) begin
                    bus_grant <= 1'b1;
                end else if (delay_cnt < GRANT_DELAY - 1) begin
                    delay_cnt <= delay_cnt + 1;
                    bus_grant <= 1'b0;
                end else begin
                    bus_grant <= 1'b1;
                end
            end else begin
                // DMA nhả bus -> Arbiter lập tức hạ grant
                bus_grant <= 1'b0;
                delay_cnt <= 4'd0;
            end
        end
    end

endmodule

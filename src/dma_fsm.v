`timescale 1ns/1ps

// Moore FSM 4 trạng thái (IDLE -> REQ_BUS -> TRANSFER -> DONE -> IDLE) điều khiển luồng DMA.
module dma_fsm (
    input  wire       clk,
    input  wire       rst_n,

    // Giao tiếp khối Thanh ghi (dma_reg)
    input  wire       dma_en,         // Bit cho phép DMA hoạt động
    output reg        dma_done,       // Xung 1 chu kỳ ở DONE để dma_reg latch ngắt
    output reg        dma_busy,       // Báo DMA đang hoạt động (khác IDLE)

    // Giao tiếp Arbiter & Ngoại vi
    input  wire       dreq,           // Yêu cầu truyền từ ngoại vi
    input  wire       bus_grant,      // CPU xác nhận nhường Bus
    output reg        bus_req,        // Xin quyền điều khiển Bus
    output reg        dack,           // Xác nhận hoàn tất với ngoại vi (ở DONE)

    // Giao tiếp khối Datapath (dma_datapath)
    input  wire       transfer_done,  // Datapath báo đã truyền xong toàn bộ byte
    output reg        start_transfer  // Kích hoạt Datapath trong suốt TRANSFER
);

    localparam [1:0] IDLE     = 2'b00;
    localparam [1:0] REQ_BUS  = 2'b01;
    localparam [1:0] TRANSFER = 2'b10;
    localparam [1:0] DONE     = 2'b11;

    reg [1:0] state;
    reg [1:0] next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:     if (dreq && dma_en) next_state = REQ_BUS;
            REQ_BUS:  if (bus_grant)      next_state = TRANSFER;
            TRANSFER: if (transfer_done)  next_state = DONE;
            DONE:                         next_state = IDLE;
            default:                      next_state = IDLE;
        endcase
    end

    // Giải mã đầu ra Moore thuần theo state để tránh glitch từ tín hiệu vào
    always @(*) begin
        bus_req        = 1'b0;
        start_transfer = 1'b0;
        dack           = 1'b0;
        dma_done       = 1'b0;
        dma_busy       = 1'b0;

        case (state)
            IDLE: ;
            REQ_BUS: begin
                bus_req  = 1'b1;
                dma_busy = 1'b1;
            end
            TRANSFER: begin
                // Giữ bus_req = 1 suốt quá trình truyền để bảo toàn quyền làm chủ bus
                bus_req        = 1'b1;
                start_transfer = 1'b1;
                dma_busy       = 1'b1;
            end
            DONE: begin
                // Hạ bus_req = 0, bật dack và xung dma_done cho dma_reg latch intr
                dack     = 1'b1;
                dma_done = 1'b1;
                dma_busy = 1'b1;
            end
            default: ;
        endcase
    end

endmodule

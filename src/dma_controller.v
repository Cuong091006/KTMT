`timescale 1ns/1ps

// Top-level DMA Controller kết nối dma_fsm (TV1), dma_reg (TV2) và dma_datapath (TV3).
// Lưu ý tích hợp cho TV2 & TV3:
// - Dùng `output wire` thay cho `output reg` để đấu nối trực tiếp output của module con (Verilog-2001).
// - Các cổng tiền tố `TV2_` / `TV3_` là tên tạm cho các tín hiệu nội bộ đang chờ TV2/TV3 chốt tên.
// - Khi nhận `TV2_dma_done == 1` tại cạnh lên clk, dma_reg cần latch `intr` và xóa `TV2_dma_en`
//   để tránh kích hoạt lại DMA ngoài ý muốn nếu `dreq` vẫn giữ mức cao.
module dma_controller (
    // Tín hiệu Hệ thống
    input  wire        clk,         // Xung nhịp hệ thống
    input  wire        rst_n,       // Reset tích cực mức thấp (Active low)

    // Giao tiếp với CPU (Slave Interface - dma_reg)
    input  wire [3:0]  cpu_addr,    // Địa chỉ thanh ghi DMA cần cấu hình
    input  wire        cpu_wr_en,   // CPU ra lệnh ghi
    input  wire        cpu_rd_en,   // CPU ra lệnh đọc
    input  wire [31:0] cpu_wr_data, // Dữ liệu CPU ghi vào cấu hình DMA
    output wire [31:0] cpu_rd_data, // Dữ liệu DMA trả về cho CPU
    output wire        intr,        // Ngắt báo hoàn thành (latch ở dma_reg)

    // Giao tiếp với Bộ nhớ/RAM (Master Interface - dma_datapath)
    output wire        bus_req,     // Xin quyền điều khiển Bus từ CPU
    input  wire        bus_grant,   // CPU đồng ý nhường Bus
    output wire [31:0] mem_addr,    // Địa chỉ RAM muốn đọc/ghi
    output wire        mem_wr_en,   // Lệnh ghi RAM
    output wire        mem_rd_en,   // Lệnh đọc RAM
    output wire [31:0] mem_wr_data, // Dữ liệu ghi vào RAM
    input  wire [31:0] mem_rd_data, // Dữ liệu đọc từ RAM
    input  wire        mem_ready,   // Trạng thái RAM sẵn sàng

    // Giao tiếp với Ngoại vi (dma_fsm giám sát)
    input  wire        dreq,        // Yêu cầu truyền DMA từ ngoại vi
    output wire        dack         // Xác nhận hoàn tất phục vụ (ở trạng thái DONE)
);

    wire        w_dma_en;         // dma_reg -> dma_fsm: cho phép DMA hoạt động
    wire        w_dma_done;       // dma_fsm -> dma_reg: xung báo trạng thái DONE
    wire        w_dma_busy;       // dma_fsm -> dma_reg: báo trạng thái bận
    wire        w_start_transfer; // dma_fsm -> dma_datapath: kích hoạt truyền
    wire        w_transfer_done;  // dma_datapath -> dma_fsm: báo truyền hết byte

    wire [31:0] w_src_addr;       // dma_reg -> dma_datapath: địa chỉ nguồn
    wire [31:0] w_dst_addr;       // dma_reg -> dma_datapath: địa chỉ đích
    wire [31:0] w_transfer_len;   // dma_reg -> dma_datapath: số byte/word cần truyền
    wire [3:0]  w_ctrl_mode;      // dma_reg -> dma_datapath: chế độ điều khiển

    dma_fsm u_dma_fsm (
        .clk            (clk),
        .rst_n          (rst_n),
        .dma_en         (w_dma_en),
        .dma_done       (w_dma_done),
        .dma_busy       (w_dma_busy),
        .dreq           (dreq),
        .bus_grant      (bus_grant),
        .bus_req        (bus_req),
        .dack           (dack),
        .transfer_done  (w_transfer_done),
        .start_transfer (w_start_transfer)
    );

    // Các cổng `TV2_*` là tên tạm chờ TV2 chốt giao tiếp module dma_reg
    dma_reg u_dma_reg (
        .clk              (clk),
        .rst_n            (rst_n),
        .cpu_addr         (cpu_addr),
        .cpu_wr_en        (cpu_wr_en),
        .cpu_rd_en        (cpu_rd_en),
        .cpu_wr_data      (cpu_wr_data),
        .cpu_rd_data      (cpu_rd_data),
        .intr             (intr),
        .TV2_dma_en       (w_dma_en),
        .TV2_dma_done     (w_dma_done),
        .TV2_dma_busy     (w_dma_busy),
        .TV2_src_addr     (w_src_addr),
        .TV2_dst_addr     (w_dst_addr),
        .TV2_transfer_len (w_transfer_len),
        .TV2_ctrl_mode    (w_ctrl_mode)
    );

    // Các cổng `TV3_*` là tên tạm chờ TV3 chốt giao tiếp module dma_datapath
    dma_datapath u_dma_datapath (
        .clk              (clk),
        .rst_n            (rst_n),
        .start_transfer   (w_start_transfer),
        .transfer_done    (w_transfer_done),
        .mem_addr         (mem_addr),
        .mem_wr_en        (mem_wr_en),
        .mem_rd_en        (mem_rd_en),
        .mem_wr_data      (mem_wr_data),
        .mem_rd_data      (mem_rd_data),
        .mem_ready        (mem_ready),
        .TV3_src_addr     (w_src_addr),
        .TV3_dst_addr     (w_dst_addr),
        .TV3_transfer_len (w_transfer_len),
        .TV3_ctrl_mode    (w_ctrl_mode)
    );

endmodule

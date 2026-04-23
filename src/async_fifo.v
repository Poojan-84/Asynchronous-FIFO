// ============================================================
// async_fifo.v
// Asynchronous FIFO — Top-Level Wrapper
//
// Instantiates and connects all 5 sub-modules:
//   - fifo_mem     : dual-port memory
//   - wptr_full    : write pointer + full flag (write domain)
//   - rptr_empty   : read pointer + empty flag (read domain)
//   - sync_r2w     : syncs rptr into write domain
//   - sync_w2r     : syncs wptr into read domain
//
// Parameters:
//   DATA_WIDTH : width of data bus       (default: 8)
//   ADDR_WIDTH : log2 of FIFO depth      (default: 4 -> 16 deep)
// ============================================================

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    // Write domain
    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wdata,
    output wire                  full,

    // Read domain
    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rdata,
    output wire                  empty
);

    // --------------------------------------------------------
    // Internal wires
    // --------------------------------------------------------
    wire [ADDR_WIDTH-1:0] waddr, raddr;       // Binary addresses to memory
    wire [ADDR_WIDTH:0]   wptr, rptr;         // Gray pointers (crossing domains)
    wire [ADDR_WIDTH:0]   wptr_sync, rptr_sync; // Synchronized Gray pointers

    // --------------------------------------------------------
    // 1. Dual-port memory
    // --------------------------------------------------------
    fifo_mem #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_fifo_mem (
        .wclk   (wclk),
        .wr_en  (wr_en & ~full),   // Guard: never write when full
        .waddr  (waddr),
        .wdata  (wdata),
        .rclk   (rclk),
        .rd_en  (rd_en & ~empty),  // Guard: never read when empty
        .raddr  (raddr),
        .rdata  (rdata)
    );

    // --------------------------------------------------------
    // 2. Write pointer + full flag (write domain)
    // --------------------------------------------------------
    wptr_full #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_wptr_full (
        .wclk       (wclk),
        .wrst_n     (wrst_n),
        .wr_en      (wr_en),
        .rptr_sync  (rptr_sync),
        .wptr       (wptr),
        .waddr      (waddr),
        .full       (full)
    );

    // --------------------------------------------------------
    // 3. Read pointer + empty flag (read domain)
    // --------------------------------------------------------
    rptr_empty #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_rptr_empty (
        .rclk       (rclk),
        .rrst_n     (rrst_n),
        .rd_en      (rd_en),
        .wptr_sync  (wptr_sync),
        .rptr       (rptr),
        .raddr      (raddr),
        .empty      (empty)
    );

    // --------------------------------------------------------
    // 4. Sync rptr (read domain) -> write domain
    // --------------------------------------------------------
    sync_r2w #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_sync_r2w (
        .wclk       (wclk),
        .wrst_n     (wrst_n),
        .rptr       (rptr),
        .rptr_sync  (rptr_sync)
    );

    // --------------------------------------------------------
    // 5. Sync wptr (write domain) -> read domain
    // --------------------------------------------------------
    sync_w2r #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_sync_w2r (
        .rclk       (rclk),
        .rrst_n     (rrst_n),
        .wptr       (wptr),
        .wptr_sync  (wptr_sync)
    );

endmodule

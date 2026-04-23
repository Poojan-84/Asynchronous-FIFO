// ============================================================
// fifo_mem.v
// Dual-Port FIFO Memory (Register Array)
//
// Purpose: Stores the actual data. Write port is clocked on
//          wclk, read port is clocked on rclk. Uses binary
//          pointers (not Gray) since it doesn't cross domains.
//
// Parameters:
//   DATA_WIDTH : number of data bits (default 8)
//   ADDR_WIDTH : number of address bits (default 4 -> depth 16)
// ============================================================

module fifo_mem #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    // Write port
    input  wire                  wclk,
    input  wire                  wr_en,      // Write enable (qualified: ~full)
    input  wire [ADDR_WIDTH-1:0] waddr,      // Binary write address
    input  wire [DATA_WIDTH-1:0] wdata,      // Data to write

    // Read port
    input  wire                  rclk,
    input  wire                  rd_en,      // Read enable (qualified: ~empty)
    input  wire [ADDR_WIDTH-1:0] raddr,      // Binary read address
    output reg  [DATA_WIDTH-1:0] rdata       // Data read out
);

    // Depth derived from address width: 2^ADDR_WIDTH entries
    localparam DEPTH = (1 << ADDR_WIDTH);

    // The actual memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // --------------------------------------------------------
    // Write port — synchronous, clocked on wclk
    // wr_en is already gated with ~full in wptr_full.v
    // --------------------------------------------------------
    always @(posedge wclk) begin
        if (wr_en)
            mem[waddr] <= wdata;
    end

    // --------------------------------------------------------
    // Read port — synchronous, clocked on rclk
    // rd_en is already gated with ~empty in rptr_empty.v
    // --------------------------------------------------------
    always @(posedge rclk) begin
        if (rd_en)
            rdata <= mem[raddr];
    end

endmodule

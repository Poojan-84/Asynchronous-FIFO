// ============================================================
// rptr_empty.v
// Read Pointer + Empty Flag Logic (Read Clock Domain)
//
// Purpose: Manages the read pointer and determines when the
//          FIFO is empty. Everything here is in the READ domain.
//
// How EMPTY is detected:
//   The read pointer (Gray) is compared against the
//   synchronized write pointer (Gray, synced into read domain
//   via sync_w2r).
//
//   The FIFO is EMPTY when the Gray read pointer equals
//   the synchronized Gray write pointer exactly (all bits).
//   This means the read side has caught up to where the
//   write side was a couple of cycles ago — safe to call empty.
// ============================================================

module rptr_empty #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire                  rd_en,          // Read request from user
    input  wire [ADDR_WIDTH:0]   wptr_sync,      // Synced Gray write pointer (from sync_w2r)

    output reg  [ADDR_WIDTH:0]   rptr,           // Gray-coded read pointer (to sync_r2w)
    output wire [ADDR_WIDTH-1:0] raddr,          // Binary read address (to fifo_mem)
    output reg                   empty           // Empty flag
);

    // --------------------------------------------------------
    // Internal binary counter (one extra bit for wrap detection)
    // --------------------------------------------------------
    reg  [ADDR_WIDTH:0] rbin;       // Binary read pointer
    wire [ADDR_WIDTH:0] rbin_next;  // Next binary value
    wire [ADDR_WIDTH:0] rgray_next; // Next Gray value

    // --------------------------------------------------------
    // Wire lower ADDR_WIDTH bits as the memory address
    // --------------------------------------------------------
    assign raddr = rbin[ADDR_WIDTH-1:0];

    // --------------------------------------------------------
    // Next pointer logic
    // Only increment when rd_en asserted AND FIFO is not empty
    // --------------------------------------------------------
    assign rbin_next  = rbin + (rd_en & ~empty);

    // Binary to Gray: gray = binary XOR (binary >> 1)
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;

    // --------------------------------------------------------
    // Register the pointers on rclk
    // --------------------------------------------------------
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin <= 0;
            rptr <= 0;
        end else begin
            rbin <= rbin_next;
            rptr <= rgray_next;
        end
    end

    // --------------------------------------------------------
    // Empty flag generation
    //
    // Empty when next Gray read pointer == synced write pointer
    // Registered to avoid glitchy combinational output
    // --------------------------------------------------------
    wire empty_val;
    assign empty_val = (rgray_next == wptr_sync);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n)
            empty <= 1'b1;  // FIFO starts empty on reset
        else
            empty <= empty_val;
    end

endmodule

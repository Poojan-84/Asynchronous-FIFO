// ============================================================
// wptr_full.v
// Write Pointer + Full Flag Logic (Write Clock Domain)
//
// Purpose: Manages the write pointer and determines when the
//          FIFO is full. Everything here is in the WRITE domain.
//
// How FULL is detected:
//   The write pointer (Gray) is compared against the
//   synchronized read pointer (also Gray, but synced into
//   write domain via sync_r2w).
//
//   In Gray code, the FIFO is FULL when:
//     - The MSB of wptr and rptr_sync are DIFFERENT
//     - The second MSB of wptr and rptr_sync are DIFFERENT
//     - All remaining bits are EQUAL
//   This works because the extra (wrap) bit flips every time
//   the pointer wraps around, letting us distinguish
//   full (pointers apart by exactly DEPTH) from empty.
// ============================================================

module wptr_full #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  wr_en,          // Write request from user
    input  wire [ADDR_WIDTH:0]   rptr_sync,      // Synced Gray read pointer (from sync_r2w)

    output reg  [ADDR_WIDTH:0]   wptr,           // Gray-coded write pointer (to sync_w2r)
    output wire [ADDR_WIDTH-1:0] waddr,          // Binary write address (to fifo_mem)
    output reg                   full            // Full flag
);

    // --------------------------------------------------------
    // Internal binary counter (one extra bit for wrap detection)
    // --------------------------------------------------------
    reg [ADDR_WIDTH:0] wbin;       // Binary write pointer
    wire [ADDR_WIDTH:0] wbin_next; // Next binary value
    wire [ADDR_WIDTH:0] wgray_next;// Next Gray value

    // --------------------------------------------------------
    // Wire the lower ADDR_WIDTH bits as the memory address
    // (drop the MSB wrap bit — it's only for full/empty logic)
    // --------------------------------------------------------
    assign waddr = wbin[ADDR_WIDTH-1:0];

    // --------------------------------------------------------
    // Next pointer logic
    // Only increment when wr_en is asserted AND FIFO is not full
    // --------------------------------------------------------
    assign wbin_next  = wbin + (wr_en & ~full);

    // Binary to Gray conversion: gray = binary XOR (binary >> 1)
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;

    // --------------------------------------------------------
    // Register the pointers on wclk
    // --------------------------------------------------------
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin <= 0;
            wptr <= 0;  // Gray 0 = 0, safe reset value
        end else begin
            wbin <= wbin_next;
            wptr <= wgray_next;
        end
    end

    // --------------------------------------------------------
    // Full flag generation (combinational, registered below)
    //
    // Full when Gray wptr_next differs from rptr_sync in:
    //   bit[ADDR_WIDTH]   (MSB)        — must be DIFFERENT
    //   bit[ADDR_WIDTH-1] (second MSB) — must be DIFFERENT
    //   bit[ADDR_WIDTH-2:0] (rest)     — must be EQUAL
    // --------------------------------------------------------
    wire full_val;
    assign full_val = (wgray_next[ADDR_WIDTH]   != rptr_sync[ADDR_WIDTH])   &&
                      (wgray_next[ADDR_WIDTH-1] != rptr_sync[ADDR_WIDTH-1]) &&
                      (wgray_next[ADDR_WIDTH-2:0] == rptr_sync[ADDR_WIDTH-2:0]);

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n)
            full <= 1'b0;
        else
            full <= full_val;
    end

endmodule

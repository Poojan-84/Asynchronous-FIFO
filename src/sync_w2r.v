// ============================================================
// sync_w2r.v
// 2-Flop Synchronizer: Write Pointer -> Read Clock Domain
//
// Purpose: Safely passes the Gray-coded write pointer from the
//          write clock domain into the read clock domain.
//          Two flip-flops in series reduce metastability risk.
// ============================================================

module sync_w2r #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  rclk,       // Read domain clock
    input  wire                  rrst_n,     // Read domain active-low reset
    input  wire [ADDR_WIDTH:0]   wptr,       // Gray-coded write pointer (write domain)
    output reg  [ADDR_WIDTH:0]   wptr_sync   // Synchronized write pointer (read domain)
);

    // Internal: first stage of the 2-FF synchronizer
    reg [ADDR_WIDTH:0] wptr_sync1;

    // Two flip-flops in series, both clocked on rclk
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            wptr_sync1 <= 0;
            wptr_sync  <= 0;
        end else begin
            wptr_sync1 <= wptr;       // Stage 1: capture (may be metastable)
            wptr_sync  <= wptr_sync1; // Stage 2: stable output
        end
    end

endmodule

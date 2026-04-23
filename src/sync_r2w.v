// ============================================================
// sync_r2w.v
// 2-Flop Synchronizer: Read Pointer -> Write Clock Domain
//
// Purpose: Safely passes the Gray-coded read pointer from the
//          read clock domain into the write clock domain.
//          Two flip-flops in series reduce metastability risk.
// ============================================================

module sync_r2w #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wclk,       // Write domain clock
    input  wire                  wrst_n,     // Write domain active-low reset
    input  wire [ADDR_WIDTH:0]   rptr,       // Gray-coded read pointer (read domain)
    output reg  [ADDR_WIDTH:0]   rptr_sync   // Synchronized read pointer (write domain)
);

    // Internal: first stage of the 2-FF synchronizer
    reg [ADDR_WIDTH:0] rptr_sync1;

    // Two flip-flops in series, both clocked on wclk
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            rptr_sync1 <= 0;
            rptr_sync  <= 0;
        end else begin
            rptr_sync1 <= rptr;       // Stage 1: capture (may be metastable)
            rptr_sync  <= rptr_sync1; // Stage 2: stable output
        end
    end

endmodule

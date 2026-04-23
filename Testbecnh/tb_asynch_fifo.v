// ============================================================
// tb_async_fifo.v
// Testbench for Asynchronous FIFO
//
// Test scenarios:
//   1. Basic write then read (slow wclk, fast rclk)
//   2. Write to full
//   3. Read to empty
//   4. Simultaneous read & write
//   5. Reset mid-operation
//   6. Fast wclk, slow rclk
// ============================================================

`timescale 1ns/1ps

module tb_async_fifo;

    // --------------------------------------------------------
    // Parameters — must match DUT
    // --------------------------------------------------------
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter DEPTH      = (1 << ADDR_WIDTH); // 16

    // --------------------------------------------------------
    // Clock periods (independent, async)
    // --------------------------------------------------------
    parameter WCLK_PERIOD = 20; // 50 MHz write clock
    parameter RCLK_PERIOD = 13; // ~77 MHz read clock (intentionally different)

    // --------------------------------------------------------
    // DUT signals
    // --------------------------------------------------------
    reg                  wclk, wrst_n;
    reg                  rclk, rrst_n;
    reg                  wr_en, rd_en;
    reg  [DATA_WIDTH-1:0] wdata;
    wire [DATA_WIDTH-1:0] rdata;
    wire                  full, empty;

    // --------------------------------------------------------
    // Scoreboard: track what we wrote, verify what we read
    // --------------------------------------------------------
    integer write_count, read_count, error_count;
    reg [DATA_WIDTH-1:0] expected_queue [0:255]; // simple array queue
    integer q_head, q_tail;

    // --------------------------------------------------------
    // Instantiate DUT
    // --------------------------------------------------------
    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .wr_en  (wr_en),
        .wdata  (wdata),
        .full   (full),
        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rd_en  (rd_en),
        .rdata  (rdata),
        .empty  (empty)
    );

    // --------------------------------------------------------
    // Clock generation — fully independent
    // --------------------------------------------------------
    initial wclk = 0;
    always #(WCLK_PERIOD/2) wclk = ~wclk;

    initial rclk = 0;
    always #(RCLK_PERIOD/2) rclk = ~rclk;

    // --------------------------------------------------------
    // VCD dump for GTKWave
    // --------------------------------------------------------
    initial begin
        $dumpfile("tb_async_fifo.vcd");
        $dumpvars(0, tb_async_fifo);
    end

    // --------------------------------------------------------
    // Helper tasks
    // --------------------------------------------------------

    // Write a single word (write clock domain)
    task do_write;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge wclk);
            #1; // small delay after edge
            if (!full) begin
                wr_en = 1;
                wdata = data;
                // Push to scoreboard queue
                expected_queue[q_tail] = data;
                q_tail = q_tail + 1;
                write_count = write_count + 1;
                @(posedge wclk);
                #1;
                wr_en = 0;
            end else begin
                $display("[WARN] Write skipped — FIFO full at time %0t", $time);
                wr_en = 0;
            end
        end
    endtask

    // Read a single word (read clock domain) and check against scoreboard
    task do_read;
        begin
            @(posedge rclk);
            #1;
            if (!empty) begin
                rd_en = 1;
                @(posedge rclk);
                #1;
                rd_en = 0;
                // Data is registered, available one cycle after rd_en
                @(posedge rclk);
                #1;
                if (rdata !== expected_queue[q_head]) begin
                    $display("[ERROR] t=%0t | Read %0d | Got=0x%02X Expected=0x%02X",
                             $time, read_count, rdata, expected_queue[q_head]);
                    error_count = error_count + 1;
                end else begin
                    $display("[OK]    t=%0t | Read %0d | Data=0x%02X",
                             $time, read_count, rdata);
                end
                q_head = q_head + 1;
                read_count = read_count + 1;
            end else begin
                $display("[WARN] Read skipped — FIFO empty at time %0t", $time);
                rd_en = 0;
            end
        end
    endtask

    // Apply reset to both domains
    task do_reset;
        begin
            wrst_n = 0;
            rrst_n = 0;
            wr_en  = 0;
            rd_en  = 0;
            wdata  = 0;
            // Hold reset for several cycles in both domains
            repeat(5) @(posedge wclk);
            repeat(5) @(posedge rclk);
            wrst_n = 1;
            rrst_n = 1;
            repeat(2) @(posedge wclk);
            repeat(2) @(posedge rclk);
            $display("[INFO] Reset released at t=%0t", $time);
        end
    endtask

    // Wait N write clock cycles
    task wclk_delay;
        input integer n;
        begin repeat(n) @(posedge wclk); end
    endtask

    // Wait N read clock cycles
    task rclk_delay;
        input integer n;
        begin repeat(n) @(posedge rclk); end
    endtask

    // --------------------------------------------------------
    // Main test sequence
    // --------------------------------------------------------
    integer i;

    initial begin
        // Init scoreboard
        write_count = 0;
        read_count  = 0;
        error_count = 0;
        q_head      = 0;
        q_tail      = 0;
        wr_en       = 0;
        rd_en       = 0;
        wdata       = 0;

        $display("============================================");
        $display("       Async FIFO Testbench Starting        ");
        $display("  DEPTH=%0d  DATA_WIDTH=%0d  WCLK=%0dns RCLK=%0dns",
                 DEPTH, DATA_WIDTH, WCLK_PERIOD, RCLK_PERIOD);
        $display("============================================");

        // --------------------------------------------------
        // TEST 1: Reset
        // --------------------------------------------------
        $display("\n--- TEST 1: Reset ---");
        do_reset;
        if (empty !== 1'b1)
            $display("[ERROR] empty should be 1 after reset, got %0b", empty);
        else
            $display("[OK]    empty=1 after reset");
        if (full !== 1'b0)
            $display("[ERROR] full should be 0 after reset, got %0b", full);
        else
            $display("[OK]    full=0 after reset");

        // --------------------------------------------------
        // TEST 2: Basic write then read (8 words)
        // --------------------------------------------------
        $display("\n--- TEST 2: Basic Write then Read (8 words) ---");
        for (i = 0; i < 8; i = i + 1)
            do_write(8'hA0 + i);

        wclk_delay(4); // let pointers propagate through synchronizers

        for (i = 0; i < 8; i = i + 1)
            do_read;

        rclk_delay(4);

        // --------------------------------------------------
        // TEST 3: Write to full
        // --------------------------------------------------
        $display("\n--- TEST 3: Write to Full ---");
        // Write DEPTH words to fill the FIFO
        for (i = 0; i < DEPTH; i = i + 1)
            do_write(8'hB0 + i);

        wclk_delay(6); // wait for full flag to propagate

        if (full)
            $display("[OK]    FIFO correctly shows full after %0d writes", DEPTH);
        else
            $display("[ERROR] FIFO should be full but full=0");

        // Attempt an extra write — should be ignored
        $display("[INFO] Attempting write while full (should be ignored)...");
        do_write(8'hFF);

        // --------------------------------------------------
        // TEST 4: Read to empty
        // --------------------------------------------------
        $display("\n--- TEST 4: Read to Empty ---");
        for (i = 0; i < DEPTH; i = i + 1)
            do_read;

        rclk_delay(6); // wait for empty flag to propagate

        if (empty)
            $display("[OK]    FIFO correctly shows empty after draining");
        else
            $display("[ERROR] FIFO should be empty but empty=0");

        // Attempt an extra read — should be ignored
        $display("[INFO] Attempting read while empty (should be ignored)...");
        do_read;

        // --------------------------------------------------
        // TEST 5: Simultaneous Read & Write
        // --------------------------------------------------
        $display("\n--- TEST 5: Simultaneous Read & Write ---");
        // Pre-fill halfway
        for (i = 0; i < 8; i = i + 1)
            do_write(8'hC0 + i);

        wclk_delay(4);

        // Now write and read at the same time using fork/join
        fork
            begin // Writer process
                for (i = 0; i < 8; i = i + 1) begin
                    @(posedge wclk); #1;
                    if (!full) begin
                        wr_en = 1;
                        wdata = 8'hD0 + i;
                        expected_queue[q_tail] = 8'hD0 + i;
                        q_tail = q_tail + 1;
                        write_count = write_count + 1;
                    end
                    @(posedge wclk); #1;
                    wr_en = 0;
                end
            end
            begin // Reader process
                for (i = 0; i < 8; i = i + 1)
                    do_read;
            end
        join

        rclk_delay(4);
        wclk_delay(4);

        // Drain remaining
        for (i = 0; i < 8; i = i + 1)
            do_read;

        rclk_delay(6);

        // --------------------------------------------------
        // TEST 6: Mid-operation Reset
        // --------------------------------------------------
        $display("\n--- TEST 6: Mid-operation Reset ---");
        // Write a few words
        for (i = 0; i < 4; i = i + 1)
            do_write(8'hE0 + i);

        $display("[INFO] Asserting reset mid-operation...");

        // Reset scoreboard too since FIFO state is cleared
        q_head = q_tail; // flush expected queue

        do_reset;

        if (empty !== 1'b1)
            $display("[ERROR] empty should be 1 after mid-op reset");
        else
            $display("[OK]    Recovered cleanly from mid-operation reset");

        // Write and read fresh after reset
        for (i = 0; i < 4; i = i + 1)
            do_write(8'hF0 + i);

        wclk_delay(4);

        for (i = 0; i < 4; i = i + 1)
            do_read;

        rclk_delay(4);

        // --------------------------------------------------
        // Final Report
        // --------------------------------------------------
        $display("\n============================================");
        $display("            SIMULATION COMPLETE             ");
        $display("  Writes : %0d", write_count);
        $display("  Reads  : %0d", read_count);
        $display("  Errors : %0d", error_count);
        if (error_count == 0)
            $display("  Result : ** ALL TESTS PASSED **");
        else
            $display("  Result : ** %0d ERRORS DETECTED **", error_count);
        $display("============================================");

        $finish;
    end

    // --------------------------------------------------------
    // Timeout watchdog — kills sim if it hangs
    // --------------------------------------------------------
    initial begin
        #500000;
        $display("[ERROR] TIMEOUT — simulation hung!");
        $finish;
    end

endmodule

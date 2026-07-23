////////////////////////////////////////////////////////////////////////////////
//
// File name    :   simple_fifo_tb.sv
// Project name :   SV_fifo_build
// Author       :   Oren Ruthstein
// Date Created :   07/2026
// Company      :   ENICS
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Self-checking testbench for simple_fifo.sv. Compares the DUT
// against a plain SystemVerilog queue used as a golden model. Do not edit this
// file - it is your judge, not part of the exercise.
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module simple_fifo_tb;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;

    logic                  clk, rst_n;
    logic                  wr_en, rd_en, full, empty;
    logic [DATA_WIDTH-1:0] wr_data, rd_data;

    simple_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH)
    ) dut (.*);

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Golden model - a plain SW queue mirroring what the FIFO should contain.
    logic [DATA_WIDTH-1:0] model_q[$];
    int errors = 0;
    int checks = 0;

    // Drives one cycle of stimulus, checking flags/rd_data against the model
    // BEFORE the edge (i.e. against the state left over from the previous
    // cycle), then advances the clock and updates the model to match.
    task automatic drive_cycle(bit do_write, bit [DATA_WIDTH-1:0] data, bit do_read);
        wr_en   = do_write;
        wr_data = data;
        rd_en   = do_read;

        if ((model_q.size() == DEPTH) !== full) begin
            errors++;
            $display("[%0t] FULL MISMATCH: expected=%0b actual=%0b (model size=%0d)",
                      $time, model_q.size() == DEPTH, full, model_q.size());
        end
        if ((model_q.size() == 0) !== empty) begin
            errors++;
            $display("[%0t] EMPTY MISMATCH: expected=%0b actual=%0b", $time, model_q.size() == 0, empty);
        end
        if (model_q.size() > 0 && rd_data !== model_q[0]) begin
            errors++;
            $display("[%0t] RD_DATA MISMATCH: expected=%0h actual=%0h", $time, model_q[0], rd_data);
        end
        checks++;

        @(posedge clk);

        if (do_write && model_q.size() < DEPTH)
            model_q.push_back(data);
        if (do_read && model_q.size() > 0)
            void'(model_q.pop_front());
    endtask

    initial begin
        rst_n   = 1'b0;
        wr_en   = 1'b0;
        rd_en   = 1'b0;
        wr_data = '0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        // Fill it up (write-only) until full
        for (int i = 0; i < DEPTH; i++)
            drive_cycle(1'b1, i[DATA_WIDTH-1:0], 1'b0);

        // Try to overfill by one - must be silently ignored
        drive_cycle(1'b1, 8'hFF, 1'b0);

        // Drain fully (read-only)
        for (int i = 0; i < DEPTH; i++)
            drive_cycle(1'b0, '0, 1'b1);

        // Try to over-read while empty - must be silently ignored
        drive_cycle(1'b0, '0, 1'b1);

        // Prime with one entry, then hammer simultaneous read+write for a while
        // (count should never change during this section - one in, one out)
        drive_cycle(1'b1, 8'hA0, 1'b0);
        repeat (10)
            drive_cycle(1'b1, $urandom_range(0, 255), 1'b1);

        // Drain whatever is left, then one final idle flag check
        repeat (DEPTH) drive_cycle(1'b0, '0, 1'b1);
        drive_cycle(1'b0, '0, 1'b0);

        if (errors == 0)
            $display("S U C C E S S - %0d checks, 0 mismatches. Your FIFO is solid.", checks);
        else
            $display("FOUND %0d MISMATCH(ES) out of %0d checks.", errors, checks);

        $finish;
    end

endmodule

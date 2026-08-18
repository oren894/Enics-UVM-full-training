////////////////////////////////////////////////////////////////////////////////
//
// File name    :   case1_blocking_vs_nonblocking.sv
// Project name :   SV_riddles
// Author       :   Oren Ruthstein
// Date Created :   07/2026
// Company      :   ENICS
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Case 1 - "The Collapsing Pipeline"
//
// SOLUTION FILE - local answer key, not for students.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __CASE1_BLOCKING_VS_NONBLOCKING
`define __CASE1_BLOCKING_VS_NONBLOCKING

`timescale 1ns/1ps

module case1_blocking_vs_nonblocking;

    logic clk;
    logic rst_n;
    logic data_in;

    /*------------------------------------------------------------------------------
    --  Reference pipeline - correct 3-stage shift register (non-blocking).
    --  Do not touch this one - it is your "known good" comparison signal.
    ------------------------------------------------------------------------------*/
    logic stage0_nb, stage1_nb, stage2_nb;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage0_nb <= 1'b0;
            stage1_nb <= 1'b0;
            stage2_nb <= 1'b0;
        end else begin
            stage0_nb <= data_in;
            stage1_nb <= stage0_nb;
            stage2_nb <= stage1_nb;
        end
    end

    /*------------------------------------------------------------------------------
    --  Exercise 1 - FIXED. Every "=" became "<=". Nothing else changed.
    --
    --  Why this was broken: with blocking assignments in a clocked block, each
    --  statement executes (and its RHS is visible to the NEXT statement)
    --  immediately, in order, on the same clock edge. So on the edge where
    --  data_in is captured, stage0_bug gets the new data_in value and then
    --  stage1_bug <= stage0_bug already reads that NEW value in the same
    --  edge - the pipeline collapses by one stage on every single edge
    --  instead of shifting one stage per cycle like real flip-flops.
    ------------------------------------------------------------------------------*/
    logic stage0_bug, stage1_bug, stage2_bug;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage0_bug <= 1'b0;
            stage1_bug <= 1'b0;
            stage2_bug <= 1'b0;
        end else begin
            stage0_bug <= data_in;
            stage1_bug <= stage0_bug;
            stage2_bug <= stage1_bug;
        end
    end

    // Clock generation
    initial clk = 1'b0;
    always #5 clk = ~clk;

    /*------------------------------------------------------------------------------
    --  Self-checking scoreboard. Since both pipelines share the same clk, rst_n
    --  and data_in, a correctly implemented stage*_bug must equal stage*_nb on
    --  EVERY cycle, forever. We compare on the falling edge, well after any
    --  same-edge assignments (blocking or non-blocking) have fully settled, so
    --  the comparison itself is race-free.
    ------------------------------------------------------------------------------*/
    int errors;

    always @(negedge clk) begin
        if (rst_n) begin
            if (stage0_nb !== stage0_bug)
                $display("[%0t] stage0 differs: nb=%0b bug=%0b", $time, stage0_nb, stage0_bug);
            if (stage1_nb !== stage1_bug)
                $display("[%0t] stage1 differs: nb=%0b bug=%0b", $time, stage1_nb, stage1_bug);
            if (stage2_nb !== stage2_bug) begin
                errors++;
                $display("[%0t] stage2 differs: nb=%0b bug=%0b  <-- final output mismatch", $time, stage2_nb, stage2_bug);
            end
        end
    end

    initial begin
        rst_n   = 1'b0;
        data_in = 1'b0;
        errors  = 0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        // Drive a pseudo-random data_in pattern so every stage gets exercised
        repeat (20) begin
            @(negedge clk);
            data_in = $urandom_range(0, 1);
        end

        repeat (5) @(negedge clk);

        if (errors == 0)
            $display("S U C C E S S - stage2_bug matched stage2_nb on every cycle.");
        else
            $display("FOUND %0d MISMATCH(ES) on stage2 - go read the waveform before you fix anything.", errors);

        $finish;
    end

endmodule

`endif // __CASE1_BLOCKING_VS_NONBLOCKING

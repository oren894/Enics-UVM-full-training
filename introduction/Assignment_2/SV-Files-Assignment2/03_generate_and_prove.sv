////////////////////////////////////////////////////////////////////////////////
//
// File name    :   03_generate_and_prove.sv
// Project name :   SV_basics
// Author       :   Oren Ruthstein
// Date Created :   07/2026
// Company      :   ENICS
//
////////////////////////////////////////////////////////////////////////////////
//
// Topics: Randomization, Assertions.
// See ../MATERIAL.md for the full task write-up and background reading.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __GENERATE_AND_PROVE
`define __GENERATE_AND_PROVE

`timescale 1ns/1ps

module generate_and_prove;

    logic clk;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    class stim_packet;
        rand bit [3:0] length;
        rand bit       urgent;

        /*--------------------------------------------------------------------------
        --  Write two constraints:
        --   - length must always be inside the range 2 to 12 (inclusive)
        --   - urgent should be 1 about 20% of the time, 0 the other 80%
        --  See the Randomization section in MATERIAL.md for the syntax.
        --------------------------------------------------------------------------*/
        // INSERT YOUR CODE HERE!
    endclass

    int lengths[$];

    /*------------------------------------------------------------------------------
    --  Part A - Randomization
    --  Create and randomize 5 stim_packet objects. For each one, $display it
    --  (length + urgent) and push its `length` field into the lengths queue
    --  below - Part B's generator consumes this queue to build its stimulus.
    --
    --  Call randomize() as a plain statement, not guarded by an "if" - with
    --  these constraints it cannot fail, so wrapping it in
    --  "if (pkt.randomize())" would just be dead code here.
    ------------------------------------------------------------------------------*/
    initial begin
        // INSERT YOUR CODE HERE!
    end

    /*------------------------------------------------------------------------------
    --  Part B - Assertions (the hard part!)
    --  The generator below (already written for you) raises req, holds it for
    --  lengths[i]+1 cycles, then pulses done for exactly one cycle while
    --  dropping req in that same cycle, before moving on to the next packet.
    --
    --  Write two assertion properties:
    --   1. p_mutex          - req and done must never be high at the same time.
    --   2. p_eventual_done  - whenever req is high, done must go high within
    --                         1 to 20 clock cycles.
    ------------------------------------------------------------------------------*/
    logic req, done;
    int   busy_cycles;

    initial begin
        req = 1'b0;
        done = 1'b0;
    end

    always_ff @(posedge clk) begin
        done <= 1'b0;
        if (!req && lengths.size() > 0) begin
            busy_cycles <= lengths.pop_front();
            req         <= 1'b1;
        end else if (req && busy_cycles > 0) begin
            busy_cycles <= busy_cycles - 1;
        end else if (req && busy_cycles == 0) begin
            req  <= 1'b0;
            done <= 1'b1;
        end
    end

    // INSERT YOUR CODE HERE! (p_mutex and p_eventual_done assert property blocks)

    // A watchdog so this never hangs forever if Part A hasn't been filled in
    // yet (lengths would stay empty and the wait below would never unblock).
    initial begin
        fork
            begin
                wait (lengths.size() > 0);
                wait (lengths.size() == 0 && !req && !done);
                #20;
                $display("Run finished. If no ASSERTION FAILURE lines appeared above, both properties held for the whole run.");
            end
            begin
                #2000;
                $display("TIMEOUT - lengths never got populated. Did you finish Part A (randomize + push_back into lengths)?");
            end
        join_any
        $finish;
    end

endmodule

`endif // __GENERATE_AND_PROVE

////////////////////////////////////////////////////////////////////////////////
//
// File name    :   case2_priority_grant.sv
// Project name :   SV_riddles
// Author       :   Oren Ruthstein
// Date Created :   07/2026
// Company      :   ENICS
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Case 2 - "The Line Cutter"
//
// SOLUTION FILE - local answer key, not for students.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __CASE2_PRIORITY_GRANT
`define __CASE2_PRIORITY_GRANT

`timescale 1ns/1ps

module case2_priority_grant (
    input  logic [3:0] req,
    output logic [3:0] grant
);

    always_comb begin
        if (req[3])
            grant = 4'b1000;
        else if (req[2])
            grant = 4'b0100;
        else if (req[1])
            grant = 4'b0010;
        else if (req[0])
            grant = 4'b0001;
        else
            grant = 4'b0000;

    end

endmodule

module case2_round_robin_arbiter (
    input  logic       clk,
    input  logic       rst_n,

    input  logic [3:0] req,
    output logic [3:0] grant
);

    logic [1:0] last_grant;   // index (0-3) of the port granted last time

    // Combinational: rotate priority order based on who won last time.
    // Each case branch is just the rotation table spelled out - starting
    // right after last_grant, wrapping through all 4 ports.
    always_comb begin
        grant = 4'b0000;
        case (last_grant)
            2'd0: begin                    // priority order: 1, 2, 3, 0
                if      (req[1]) grant = 4'b0010;
                else if (req[2]) grant = 4'b0100;
                else if (req[3]) grant = 4'b1000;
                else if (req[0]) grant = 4'b0001;
            end
            2'd1: begin                    // priority order: 2, 3, 0, 1
                if      (req[2]) grant = 4'b0100;
                else if (req[3]) grant = 4'b1000;
                else if (req[0]) grant = 4'b0001;
                else if (req[1]) grant = 4'b0010;
            end
            2'd2: begin                    // priority order: 3, 0, 1, 2
                if      (req[3]) grant = 4'b1000;
                else if (req[0]) grant = 4'b0001;
                else if (req[1]) grant = 4'b0010;
                else if (req[2]) grant = 4'b0100;
            end
            2'd3: begin                    // priority order: 0, 1, 2, 3
                if      (req[0]) grant = 4'b0001;
                else if (req[1]) grant = 4'b0010;
                else if (req[2]) grant = 4'b0100;
                else if (req[3]) grant = 4'b1000;
            end
        endcase
    end

    // Sequential: remember who just won, so next cycle's rotation starts
    // right after them. Resets to 2'd3 so the very first cycle after reset
    // checks port0 first.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            last_grant <= 2'd3;
        else if (grant != 4'b0000)
            last_grant <= grant[0] ? 2'd0 :
                          grant[1] ? 2'd1 :
                          grant[2] ? 2'd2 : 2'd3;
    end

endmodule

module case2_priority_grant_tb;

    // --- Fixed-priority baseline (case2_priority_grant) ------------------
    logic [3:0] req_fixed, grant_fixed, expected_grant_fixed;
    int errors_fixed;

    case2_priority_grant dut_fixed (
        .req   (req_fixed),
        .grant (grant_fixed)
    );

    function automatic logic [3:0] priority_model(logic [3:0] r);
        if (r[3])      return 4'b1000;
        else if (r[2]) return 4'b0100;
        else if (r[1]) return 4'b0010;
        else if (r[0]) return 4'b0001;
        else           return 4'b0000;
    endfunction

    // --- Round-robin arbiter (case2_round_robin_arbiter) -----------------
    logic       clk, rst_n;
    logic [3:0] req_rr, grant_rr;

    case2_round_robin_arbiter dut_rr (
        .clk   (clk),
        .rst_n (rst_n),
        .req   (req_rr),
        .grant (grant_rr)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Golden model - mirrors the DUT's own spec: priority this cycle rotates
    // starting right after whoever won last time.
    int unsigned model_last_grant;

    function automatic int rr_grant_idx(logic [3:0] req_in, int unsigned last_idx);
        for (int offset = 1; offset <= 4; offset++) begin
            int idx = (last_idx + offset) % 4;
            if (req_in[idx]) return idx;
        end
        return -1;
    endfunction

    int errors_rr = 0;
    int checks_rr = 0;

    // Per-port "how many consecutive cycles has this port been requesting
    // without winning" - tracked during the continuous-request phase below.
    int wait_cycles[4];
    int max_wait[4];

    task automatic drive_cycle(logic [3:0] req_in);
        int              exp_idx;
        logic [3:0]      exp_grant;

        req_rr = req_in;
        #1;

        exp_idx   = rr_grant_idx(req_rr, model_last_grant);
        exp_grant = '0;
        if (exp_idx != -1)
            exp_grant[exp_idx] = 1'b1;

        if (grant_rr !== exp_grant) begin
            errors_rr++;
            $display("[%0t] GRANT MISMATCH: req=%b expected=%b actual=%b (model_last_grant=%0d)",
                      $time, req_rr, exp_grant, grant_rr, model_last_grant);
        end
        checks_rr++;

        for (int p = 0; p < 4; p++) begin
            if (grant_rr[p]) begin
                if (wait_cycles[p] > max_wait[p]) max_wait[p] = wait_cycles[p];
                wait_cycles[p] = 0;
            end else if (req_rr[p]) begin
                wait_cycles[p]++;
                if (wait_cycles[p] > max_wait[p]) max_wait[p] = wait_cycles[p];
            end else begin
                wait_cycles[p] = 0;
            end
        end

        @(posedge clk);

        if (exp_idx != -1)
            model_last_grant = exp_idx;
    endtask

    initial begin
        // --- Step 1: baseline sweep - prove the fixed-priority module still
        // behaves like a plain priority encoder for every req combination.
        errors_fixed = 0;
        for (int i = 0; i < 16; i++) begin
            req_fixed = i[3:0];
            #10;
            expected_grant_fixed = priority_model(req_fixed);
            if (grant_fixed !== expected_grant_fixed) begin
                errors_fixed++;
                $display("[%0t] BASELINE MISMATCH: req=%b  grant=%b  expected=%b",
                          $time, req_fixed, grant_fixed, expected_grant_fixed);
            end
        end
        if (errors_fixed == 0)
            $display("Baseline OK - case2_priority_grant matches the priority model for all 16 req combinations.");

        // --- Step 2: demonstrate the actual customer complaint - hold every
        // port's request high and show the fixed-priority module never once
        // grants port0 (or port1/port2).
        req_fixed = 4'b1111;
        #10;
        $display("[%0t] Customer complaint reproduced: req=1111 (everyone asking) -> grant=%b every single cycle. Port0 never wins.",
                  $time, grant_fixed);

        // --- Step 3: round-robin arbiter -------------------------------
        rst_n  = 1'b0;
        req_rr = '0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        model_last_grant = 3;   // matches the DUT's reset value (2'd3)

        // Sanity: a lone requester should be granted every cycle it asks.
        repeat (5)
            drive_cycle(4'b0001);   // port0 only

        // Fairness / anti-starvation: everyone requests every cycle, back to
        // back, for several full rotations - this is the customer's scenario.
        for (int p = 0; p < 4; p++) begin
            wait_cycles[p] = 0;
            max_wait[p]    = 0;
        end
        repeat (16)
            drive_cycle(4'b1111);

        for (int p = 0; p < 4; p++) begin
            if (max_wait[p] > 3) begin
                errors_rr++;
                $display("STARVATION on port%0d: waited %0d cycles for a grant while continuously requesting (limit 3).",
                          p, max_wait[p]);
            end else begin
                $display("port%0d fairness OK: longest wait while continuously requesting was %0d cycle(s).",
                          p, max_wait[p]);
            end
        end

        // Directed: only port0 and port2 request; confirms the rotation
        // correctly skips ports that aren't asking.
        repeat (10)
            drive_cycle(4'b0101);

        // Randomized.
        repeat (300)
            drive_cycle($urandom_range(0, 15));

        if (errors_fixed == 0 && errors_rr == 0)
            $display("S U C C E S S - baseline intact, %0d round-robin checks, 0 mismatches, no starvation.", checks_rr);
        else
            $display("FOUND %0d baseline mismatch(es) and %0d round-robin mismatch(es)/starvation event(s).",
                      errors_fixed, errors_rr);

        $finish;
    end

endmodule

`endif // __CASE2_PRIORITY_GRANT

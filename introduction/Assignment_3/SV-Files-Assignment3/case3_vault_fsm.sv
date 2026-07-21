////////////////////////////////////////////////////////////////////////////////
//
// File name    :   case3_vault_fsm.sv
// Project name :   SV_riddles
// Author       :
// Date Created :
// Company      :   Team Training
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Case 3 - "The Eager Door"
//
// A small lock-acquisition FSM (LOCKED -> MAYBE -> OPEN, needs two consecutive
// key_pulse cycles to open, same shape as the real dma_rx_fsm you will meet in
// the full practical environment). door_open is wired to the wrong signal.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __CASE3_VAULT_FSM
`define __CASE3_VAULT_FSM

`timescale 1ns/1ps

module case3_vault_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic key_pulse,
    output logic door_open
);

    typedef enum logic [1:0] {VAULT_LOCKED, VAULT_MAYBE, VAULT_OPEN} vault_state_t;

    vault_state_t state, next_state;

    // State register - correct. This is NOT where the bug is.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= VAULT_LOCKED;
        else
            state <= next_state;
    end

    // Next-state logic - also correct.
    always_comb begin
        next_state = state;
        case (state)
            VAULT_LOCKED: if (key_pulse) next_state = VAULT_MAYBE;
            VAULT_MAYBE:  next_state = key_pulse ? VAULT_OPEN : VAULT_LOCKED;
            VAULT_OPEN:   if (!key_pulse) next_state = VAULT_LOCKED;
            default:      next_state = VAULT_LOCKED;
        endcase
    end

    /*------------------------------------------------------------------------------
    --  Exercise 3 - door_open should go high on the SAME clock cycle that `state`
    --  (the registered, current FSM state) actually reaches VAULT_OPEN - not one
    --  cycle earlier. Put clk, rst_n, key_pulse, state, next_state and door_open
    --  together on the waveform and find out which signal door_open is really
    --  watching.
    ------------------------------------------------------------------------------*/
    assign door_open = (next_state == VAULT_OPEN);

endmodule

module case3_vault_fsm_tb;

    logic clk, rst_n, key_pulse, door_open;
    int errors;

    case3_vault_fsm dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .key_pulse (key_pulse),
        .door_open (door_open)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Independent, testbench-side reference model of the intended behavior.
    typedef enum logic [1:0] {R_LOCKED, R_MAYBE, R_OPEN} ref_state_t;
    ref_state_t ref_state;
    logic ref_door_open;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ref_state <= R_LOCKED;
        else begin
            case (ref_state)
                R_LOCKED: if (key_pulse) ref_state <= R_MAYBE;
                R_MAYBE:  ref_state <= key_pulse ? R_OPEN : R_LOCKED;
                R_OPEN:   if (!key_pulse) ref_state <= R_LOCKED;
                default:  ref_state <= R_LOCKED;
            endcase
        end
    end

    assign ref_door_open = (ref_state == R_OPEN);

    // #1 pushes the check to a distinctly later simulation time than the
    // negedge stimulus writes below, so it always samples fully-settled
    // values - no race between "driving key_pulse" and "checking door_open".
    always @(negedge clk) begin
        #1;
        if (rst_n && (door_open !== ref_door_open)) begin
            errors++;
            $display("[%0t] MISMATCH: door_open=%0b  expected=%0b", $time, door_open, ref_door_open);
        end
    end

    initial begin
        rst_n     = 1'b0;
        key_pulse = 1'b0;
        errors    = 0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        // Attempt 1: a single pulse then release - must NOT open (needs 2 in a row)
        @(negedge clk); key_pulse = 1'b1;
        @(negedge clk); key_pulse = 1'b0;
        repeat (2) @(negedge clk);

        // Attempt 2: two consecutive pulses - should open and stay open
        @(negedge clk); key_pulse = 1'b1;
        @(negedge clk); key_pulse = 1'b1;
        repeat (3) @(negedge clk);

        // release key_pulse - door should close again
        @(negedge clk); key_pulse = 1'b0;
        repeat (3) @(negedge clk);

        if (errors == 0)
            $display("S U C C E S S - door_open matched the reference model on every cycle.");
        else
            $display("FOUND %0d MISMATCH(ES) - compare state vs next_state vs door_open in the waveform.", errors);

        $finish;
    end

endmodule

`endif // __CASE3_VAULT_FSM

////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_virtual_sequence.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Simplified virtual sequence for the basic exercise test.
//              Only LOCK_REGULAR — sends clean packets to lock, then sends
//              more clean packets. No junk, no phase, no errors.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_VIRTUAL_SEQUENCE
`define __RX_VIRTUAL_SEQUENCE

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
class rx_virtual_sequence extends uvm_sequence;

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_object_utils        (rx_virtual_sequence)
    `uvm_declare_p_sequencer (rx_virtual_sequencer) 

    /*------------------------------------------------------------------------------
    -- Parameters.
    ------------------------------------------------------------------------------*/
    rx_generation_parameters parameters = null;

    /*------------------------------------------------------------------------------
    -- Members.
    ------------------------------------------------------------------------------*/
    int unsigned lock_valid_threshold_val;

    /*------------------------------------------------------------------------------
    -- Nested Sequences.
    ------------------------------------------------------------------------------*/
    rx_input_data_sequence input_data_sequence = null;

    rand int unsigned num_msgs; // Randomized stimulus field
    constraint num_msgs_c { // UVM Randomization constraint block
        num_msgs inside {[this.parameters.MIN_MESSAGES_IN_REGULAR_TEST : this.parameters.MAX_MESSAGES_IN_REGULAR_TEST]};
    }

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new(string name = "rx_virtual_sequence");
        super.new(name);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Pre start.
    -------------------------------------------------------------------------------*/
    task pre_start();

        // Raise objection
        if ((get_parent_sequence() == null) && (starting_phase != null)) begin
            starting_phase.raise_objection(this, "Starting");
        end 
    endtask

    /*------------------------------------------------------------------------------
    -- Pre randomize.
    ------------------------------------------------------------------------------*/
    function void pre_randomize();

        // Get the parameters from the test.
        if(!uvm_config_db #(rx_generation_parameters)::get(null, this.get_full_name(), "parameters", this.parameters)) begin
            `uvm_fatal(this.get_name().toupper(), "Couldn't find the generation parameters")
        end 

        // Get lock_valid_threshold_val
        if(!uvm_config_db #(int unsigned)::get(null, "*", "lock_valid_threshold_val", this.lock_valid_threshold_val)) begin
             `uvm_fatal(this.get_name().toupper(), "Couldn't find lock_valid_threshold_val")
        end 
    endfunction

    /*-------------------------------------------------------------------------------
    -- Body.
    -- 1. Send lock_valid_threshold_val clean packets to lock the DUT (LOCK_REGULAR).
    -- 2. Send num_msgs more clean packets as normal traffic.
    -------------------------------------------------------------------------------*/
    task body();
        `uvm_info(get_name(), $sformatf("Starting basic test: LVT=%0d, num_msgs=%0d", lock_valid_threshold_val, num_msgs), UVM_LOW)
        
        // ── Phase 1: Lock the DUT ──
        // Send lock_valid_threshold_val clean packets (no junk, no errors)
        `uvm_info(get_name(), "Executing LOCK_REGULAR scenario...", UVM_LOW)
        repeat(lock_valid_threshold_val) begin
            `uvm_do_on(input_data_sequence, p_sequencer.input_data_sequencer)
        end

        // ── Phase 2: Send traffic after lock ──
        `uvm_info(get_name(), $sformatf("DUT locked. Sending %0d messages...", num_msgs), UVM_LOW)
        repeat(num_msgs) begin
            `uvm_do_on(input_data_sequence, p_sequencer.input_data_sequencer)
        end
    endtask

    /*-------------------------------------------------------------------------------
    -- Post start.
    -------------------------------------------------------------------------------*/
    task post_start();

        // Drop objection
        if ((get_parent_sequence() == null) && (starting_phase != null)) begin
            `uvm_info(get_name(), "Virtual sequence finished.", UVM_LOW)
            starting_phase.drop_objection(this, "Ending");
        end
    endtask
endclass

`endif // __RX_VIRTUAL_SEQUENCE

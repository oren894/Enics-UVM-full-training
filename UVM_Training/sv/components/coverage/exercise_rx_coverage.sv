////////////////////////////////////////////////////////////////////////////////
//
// File name    : exercise_rx_coverage.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 05/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Simplified UVM coverage subscriber for the basic exercise test.
//              Only two coverpoints:
//                1. length  – bins for the different packet lengths
//                2. got_locked – confirms the DUT achieved lock
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_COVERAGE
`define __RX_COVERAGE

import uvm_pkg::*;

`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
class rx_coverage extends uvm_subscriber #(rx_coverage_item);

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_component_utils(rx_coverage) // Factory registration macro

    /*------------------------------------------------------------------------------
    -- Cover Groups
    ------------------------------------------------------------------------------*/
    // =============================================================================
    // Functional Coverage Model
    // -----------------------------------------------------------------------------
    // Simplified covergroup with only two coverpoints:
    //   length     – packet length bins (sampled for normal packets only)
    //   got_locked – confirms the MAYBE_LOCKED → LOCKED transition occurred
    // =============================================================================
    covergroup rx_cg with function sample(rx_coverage_item message);
        option.per_instance = 1; 
        
        // Packet length – sampled only for normal packets (not state-transition items)
        length: coverpoint message.length iff (!message.is_state_transition) {        
            bins min_len = {rx_verification_pack::MIN_DATA_SIZE};
            bins zero_to_1k = {[rx_verification_pack::MIN_DATA_SIZE+1:1023]};
            bins one_to_2k = {[1024:2047]};
            bins two_to_3k = {[2048:3071]};
            bins three_to_4k = {[3072:4095]};
            bins optimal_len = {rx_verification_pack::OPTIMAL_DATA_SIZE};
            bins four_to_5k = {[4097:5119]};
            bins five_to_6k = {[5120:6143]};
            bins six_to_7k = {[6144:7167]};
            bins seven_to_max = {[7168:rx_verification_pack::MAX_DATA_SIZE-1]};
            bins max_len = {rx_verification_pack::MAX_DATA_SIZE};
        }

        // Lock achieved – sampled only when got_locked is asserted (state-transition item)
        lock_achieved: coverpoint message.got_locked iff (message.is_state_transition && message.got_locked == 1) {
            bins achieved = {1};
        }
    endgroup

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_coverage", uvm_component parent = null);
        super.new (name, parent);
        rx_cg = new();
    endfunction

    /*-------------------------------------------------------------------------------
    -- Build Phase
    -------------------------------------------------------------------------------*/
    // =============================================================================
    // Build Phase
    // -----------------------------------------------------------------------------
    // The UVM build_phase is executed top-down. It is responsible for retrieving
    // configuration objects from the UVM configuration database, computing local
    // configuration values, and instantiating lower-level UVM components.
    // =============================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    /*------------------------------------------------------------------------------
    -- Write Function (UVM Subscriber)
    ------------------------------------------------------------------------------*/
    virtual function void write(rx_coverage_item t);
        rx_cg.sample(t);
    endfunction

endclass

`endif // __RX_COVERAGE

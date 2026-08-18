////////////////////////////////////////////////////////////////////////////////
//
// File name    : final_rx_coverage_item.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Item containing coverage statistics sampled from the reference model.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_COVERAGE_ITEM
`define __RX_COVERAGE_ITEM

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
class rx_coverage_item extends uvm_object;

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    bit [15:0] length;
    bit [15:0] control;
    int        num_errors_length_crc;
    int        num_errors_control_crc;
    bit        parity_error;              // 0 = valid, 1 = invalid
    int        locked_phase;
    bit        ten_transactions_done_flag; // 1 when >=10 MIN→4K→MID sequences seen
    
    // Custom state tracking metrics
    bit        is_state_transition;        // 1 if this is a dummy packet to record a state drop/lock mid-parsing
    bit        got_locked;
    int        consecutive_packets_dropped; // Consecutive packets parsed successfully before dropping from MAYBE to NO LOCK

    /*-------------------------------------------------------------------------------
    -- UVM Macros.
    -------------------------------------------------------------------------------*/
    `uvm_object_utils(rx_coverage_item) // Factory registration macro

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_coverage_item");
        super.new(name);
    endfunction

endclass

`endif // __RX_COVERAGE_ITEM

////////////////////////////////////////////////////////////////////////////////
//
// File name    : exercise_rx_coverage_item.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 05/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Simplified coverage item for the basic exercise test.
//              Only carries the fields needed by the two exercise coverpoints:
//              packet length and got_locked indication.
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
    bit [15:0] length;                      // Packet length (bytes)
    bit        got_locked;                  // 1 when MAYBE_LOCKED transitions to LOCKED
    bit        is_state_transition;         // 1 for dedicated state-transition items (not a real packet)

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

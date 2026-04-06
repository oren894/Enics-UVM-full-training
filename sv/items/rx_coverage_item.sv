////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_coverage_item.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : EniCS
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

class rx_coverage_item extends uvm_object;

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    bit [15:0] length;
    bit [15:0] control;
    int        num_errors_length_crc;
    int        num_errors_control_crc;
    bit        parity_error; // 0 for valid, 1 for invalid
    int        locked_phase;

    /*-------------------------------------------------------------------------------
    -- UVM Macros.
    -------------------------------------------------------------------------------*/
    `uvm_object_utils(rx_coverage_item)

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_coverage_item");
        super.new(name);
    endfunction

endclass

`endif // __RX_COVERAGE_ITEM

////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_virtual_sequencer.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Virtual sequencer acting as a central hub to route sequences to the appropriate physical agent sequencers (input, config, parity).
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_VIRTUAL_SEQUENCER
`define __RX_VIRTUAL_SEQUENCER

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
class rx_virtual_sequencer extends uvm_sequencer ;

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_component_utils(rx_virtual_sequencer) // Factory registration macro

    /*-------------------------------------------------------------------------------
    -- Member
    -------------------------------------------------------------------------------*/
    dv_sequencer #(rx_verification_pack::INPUT_DATA_WIDTH, rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH) input_data_sequencer           = null;

    /*-------------------------------------------------------------------------------
    -- Constructor
    -------------------------------------------------------------------------------*/
    function new(string name = "rx_virtual_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

`endif // __RX_VIRTUAL_SEQUENCER
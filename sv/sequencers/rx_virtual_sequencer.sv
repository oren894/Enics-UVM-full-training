////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_virtual_sequencer.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Virtual sequencer for the module rx.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_VIRTUAL_SEQUENCER
`define __RX_VIRTUAL_SEQUENCER

import uvm_pkg::*;
`include "uvm_macros.svh"

class rx_virtual_sequencer extends uvm_sequencer ;

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_component_utils(rx_virtual_sequencer)

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
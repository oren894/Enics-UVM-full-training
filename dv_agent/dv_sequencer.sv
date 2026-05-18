////////////////////////////////////////////////////////////////////////////////
//
// File name    : dv_sequencer.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : ENICS
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Sequencer for the DV interface.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __DV_SEQUENCER
`define __DV_SEQUENCER

import uvm_pkg::*;
`include "uvm_macros.svh"

class dv_sequencer #(parameter int DATA_WIDTH = 4, parameter int SEQUENCE_ITEM_WIDTH = DATA_WIDTH) extends uvm_sequencer #(dv_sequence_item #(SEQUENCE_ITEM_WIDTH));

    /*-------------------------------------------------------------------------------
    -- UVM Macros.
    -------------------------------------------------------------------------------*/
    `uvm_component_param_utils(dv_sequencer #(DATA_WIDTH, SEQUENCE_ITEM_WIDTH))

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "dv_sequencer", uvm_component parent = null);
        super.new (name, parent);
    endfunction
endclass

`endif // __DV_SEQUENCER
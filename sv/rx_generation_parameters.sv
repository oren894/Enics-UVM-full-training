////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_generation_parameters.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Generation parameters for the module rx.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_GENERATION_PARAMETERS
`define __RX_GENERATION_PARAMETERS

import uvm_pkg::*;
`include "uvm_macros.svh"

class rx_generation_parameters extends uvm_object; 

    /*-------------------------------------------------------------------------------
    -- Number of sequences
    -------------------------------------------------------------------------------*/
    int unsigned input_data_seq_num_of_calls = 100;

    /*------------------------------------------------------------------------------
    -- Message size probabilities
    ------------------------------------------------------------------------------*/

    /*------------------------------------------------------------------------------
    -- Valid and Ready probabilities for the agent
    ------------------------------------------------------------------------------*/
    int unsigned INPUT_DATA_VALID_PROBABILITY = 50;

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_generation_parameters");
        super.new (name);
    endfunction
endclass

`endif // __RX_GENERATION_PARAMETERS
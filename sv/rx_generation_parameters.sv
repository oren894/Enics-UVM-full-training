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

    /*------------------------------------------------------------------------------
    -- Message size probabilities
    ------------------------------------------------------------------------------*/

    /*------------------------------------------------------------------------------
    -- Valid and Ready probabilities for the agent
    ------------------------------------------------------------------------------*/
    rand int unsigned INPUT_DATA_VALID_PROBABILITY;

    constraint valid_prob_c {
        // 1   = Deterministic 1:4 (1-0-0-0 pattern)
        // 25  = Probabilistic 25% valid per cycle
        // 100 = Constant 1 (Always valid)
        INPUT_DATA_VALID_PROBABILITY dist {
            1   :/ 34,
            25  :/ 33,
            100 :/ 33
        };
    }

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_generation_parameters");
        super.new (name);
    endfunction
endclass

`endif // __RX_GENERATION_PARAMETERS
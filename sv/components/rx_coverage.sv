////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_coverage.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : EniCS
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Item to send to the module rx.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_COVERAGE
`define __RX_COVERAGE

import uvm_pkg::*;

`include "uvm_macros.svh"

class rx_coverage extends uvm_component;

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_component_utils(rx_coverage)



    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    
   

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_coverage", uvm_component parent = null);
        super.new (name, parent);
        message_length_cg = new();
    endfunction



    /*------------------------------------------------------------------------------
    --Cover Groups
    ------------------------------------------------------------------------------*/
    

    covergroup message_length_cg with sample(rx_item message);
        length: coverpoint message.length_field{        
            bins min_len = {rx_verification_pack::MIN_MESSAGE_LENGTH};
            bins max_len = {rx_verification_pack::MAX_MESSAGE_LENGTH};
            bins mid_len = {[rx_verification_pack::MIN_MESSAGE_LENGTH+1:rx_verification_pack::MAX_MESSAGE_LENGTH-1]};
        }
    endgroup

    /*------------------------------------------------------------------------------
    -- Sample Function.
    ------------------------------------------------------------------------------*/
    virtual function void sample(rx_item message);
        message_length_cg.sample(message);
    endfunction

endclass

`endif // __RX_COVERAGE
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

class rx_coverage extends uvm_subscriber #(rx_coverage_item);

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_component_utils(rx_coverage)

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    int unsigned lock_valid_threshold_val;

    /*------------------------------------------------------------------------------
    -- Cover Groups
    ------------------------------------------------------------------------------*/
    covergroup rx_cg with function sample(rx_coverage_item message, int unsigned lock_valid_threshold_val);
        // length
        length: coverpoint message.length {        
            bins min_len = {rx_verification_pack::MIN_DATA_SIZE};
            bins mid_len = {[rx_verification_pack::MIN_DATA_SIZE+1:rx_verification_pack::MAX_DATA_SIZE-1]};
            bins max_len = {rx_verification_pack::MAX_DATA_SIZE};
        }

        // control
        control: coverpoint message.control;

        // number of errors in length+crc
        length_crc_errors: coverpoint message.num_errors_length_crc {
            bins zero_errors = {0};
            bins one_error = {1};
            bins two_or_more_errors = {2};
        }

        // number of errors in control+crc
        control_crc_errors: coverpoint message.num_errors_control_crc {
            bins zero_errors = {0};
            bins one_error = {1};
        }

        // parity valid/not valid
        parity_validity: coverpoint message.parity_error {
            bins valid = {0};
            bins invalid = {1};
        }

        // phase item (locked phase 0-7)
        phase_item: coverpoint message.locked_phase {
            bins locked_phase_vals[] = {[0:7]};
        }

        // lock valid threshold
        lock_threshold: coverpoint lock_valid_threshold_val {
            bins min_th = {rx_verification_pack::MIN_LOCK_VALID_THRESHOLD};
            bins max_th = {rx_verification_pack::MAX_LOCK_VALID_THRESHOLD};
            bins mid_th = {[rx_verification_pack::MIN_LOCK_VALID_THRESHOLD+1 : rx_verification_pack::MAX_LOCK_VALID_THRESHOLD-1]};
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
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(int unsigned)::get(null, "*", "lock_valid_threshold_val", this.lock_valid_threshold_val)) begin
            `uvm_fatal(get_type_name(), "Couldn't find lock_valid_threshold_val in config_db")
        end
    endfunction

    /*------------------------------------------------------------------------------
    -- Write Function (UVM Subscriber)
    ------------------------------------------------------------------------------*/
    virtual function void write(rx_coverage_item t);
        rx_cg.sample(t, lock_valid_threshold_val);
    endfunction
    
    // Kept for backwards compatibility if called directly
    virtual function void sample(rx_coverage_item message);
        rx_cg.sample(message, lock_valid_threshold_val);
    endfunction

endclass

`endif // __RX_COVERAGE
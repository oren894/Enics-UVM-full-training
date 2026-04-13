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
        option.per_instance = 1; 
        
        // length
        length: coverpoint message.length {        
            bins min_len = {rx_verification_pack::MIN_DATA_SIZE};
            bins optimal_len = {rx_verification_pack::OPTIMAL_DATA_SIZE};
            bins mid_len = {[rx_verification_pack::MIN_DATA_SIZE+1:rx_verification_pack::MAX_DATA_SIZE-1]};
            bins max_len = {rx_verification_pack::MAX_DATA_SIZE};
        }

        // control
        control: coverpoint message.control{
            bins control_0 = {0};
            bins control_not_0 = {[1 : 2**rx_verification_pack::CONTROL_DATA_WIDTH-1]};
        }

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

        // phase item (locked phase, 4-bit nibble so phase N == phase N+4)
        phase_item: coverpoint message.locked_phase {
            bins phase_0 = {0, 4};
            bins phase_1 = {1, 5};
            bins phase_2 = {2, 6};
            bins phase_3 = {3, 7};
        }

        // lock valid threshold
        lock_threshold: coverpoint lock_valid_threshold_val {
            bins th = {[rx_verification_pack::MIN_LOCK_VALID_THRESHOLD : rx_verification_pack::MAX_LOCK_VALID_THRESHOLD]};
        }

        // Ten-transaction-sequence completion flag.
        // Coverage is met ONLY when the flag is 1 (>=10 valid MIN→4K→MID sequences seen).
        // When the flag is 0 the sample is IGNORED and does NOT affect coverage percentage.
        ten_transactions_done: coverpoint message.ten_transactions_done_flag {
            bins         done   = {1}; // ← this is the ONLY bin that must be hit
            ignore_bins  not_done = {0}; // ← 0 is ignored; sampling it has zero effect
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

    /*------------------------------------------------------------------------------
    -- Print Coverage
    -- Call this function at any point during simulation to print a formatted
    -- coverage summary to the CLI.
    ------------------------------------------------------------------------------*/
    virtual function void print_coverage();
        real overall_cov;
        string report_str;
        string line_str;

        overall_cov = rx_cg.get_coverage();

        report_str = "\n";
        report_str = {report_str, "  +===========================================================+\n"};
        report_str = {report_str, "  ||           >>> COVERAGE REPORT (SNAPSHOT) <<<             ||\n"};
        report_str = {report_str, "  +===========================================================+\n"};
        report_str = {report_str, "  |                                                           |\n"};

        $sformat(line_str,        "  |   %-30s : %6.2f%%                |\n", "length",             rx_cg.length.get_coverage());
        report_str = {report_str, line_str};
        $sformat(line_str,        "  |   %-30s : %6.2f%%                |\n", "control",            rx_cg.control.get_coverage());
        report_str = {report_str, line_str};
        $sformat(line_str,        "  |   %-30s : %6.2f%%                |\n", "length_crc_errors",  rx_cg.length_crc_errors.get_coverage());
        report_str = {report_str, line_str};
        $sformat(line_str,        "  |   %-30s : %6.2f%%                |\n", "control_crc_errors", rx_cg.control_crc_errors.get_coverage());
        report_str = {report_str, line_str};
        $sformat(line_str,        "  |   %-30s : %6.2f%%                |\n", "parity_validity",    rx_cg.parity_validity.get_coverage());
        report_str = {report_str, line_str};
        $sformat(line_str,        "  |   %-30s : %6.2f%%                |\n", "phase_item",         rx_cg.phase_item.get_coverage());
        report_str = {report_str, line_str};
        $sformat(line_str,        "  |   %-30s : %6.2f%%                |\n", "lock_threshold",         rx_cg.lock_threshold.get_coverage());
        report_str = {report_str, line_str};
        $sformat(line_str,        "  |   %-30s : %6.2f%%                |\n", "ten_transactions_done",  rx_cg.ten_transactions_done.get_coverage());
        report_str = {report_str, line_str};

        report_str = {report_str, "  |                                                           |\n"};
        report_str = {report_str, "  +-----------------------------------------------------------+\n"};
        $sformat(line_str,        "  |   %-30s : %6.2f%%                |\n", "OVERALL COVERAGE",   overall_cov);
        report_str = {report_str, line_str};
        report_str = {report_str, "  +===========================================================+\n"};

        `uvm_info("COVERAGE_REPORT", report_str, UVM_NONE)
    endfunction

endclass

`endif // __RX_COVERAGE
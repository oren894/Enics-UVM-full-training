////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_coverage.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: UVM coverage subscriber tracking functional coverage of packet properties, phase alignments, lock types, and error scenarios.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_COVERAGE
`define __RX_COVERAGE

import uvm_pkg::*;

`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
class rx_coverage extends uvm_subscriber #(rx_coverage_item);

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_component_utils(rx_coverage) // Factory registration macro

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    int unsigned lock_valid_threshold_val;
    int unsigned valid_probability;

    /*------------------------------------------------------------------------------
    -- Cover Groups
    ------------------------------------------------------------------------------*/
    // =============================================================================
    // Functional Coverage Model
    // -----------------------------------------------------------------------------
    // Defines the coverpoints and crosses required to measure the verification
    // progress. Ensures that all interesting data combinations, state transitions,
    // and boundary conditions have been successfully stimulated during the test.
    // =============================================================================
    covergroup rx_cg with function sample(rx_coverage_item message, int unsigned lock_valid_threshold_val, int unsigned valid_probability);
        option.per_instance = 1; 
        
        // length
        length: coverpoint message.length iff (!message.is_state_transition) {        
            bins min_len = {rx_verification_pack::MIN_DATA_SIZE};
            bins zero_to_1k = {[rx_verification_pack::MIN_DATA_SIZE+1:1023]};
            bins one_to_2k = {[1024:2047]};
            bins two_to_3k = {[2048:3071]};
            bins three_to_4k = {[3072:4095]};
            bins optimal_len = {rx_verification_pack::OPTIMAL_DATA_SIZE};
            bins four_to_5k = {[4097:5119]};
            bins five_to_6k = {[5120:6143]};
            bins six_to_7k = {[6144:7167]};
            bins seven_to_max = {[7168:rx_verification_pack::MAX_DATA_SIZE-1]};
            bins max_len = {rx_verification_pack::MAX_DATA_SIZE};
        }

        // control
        control: coverpoint message.control iff (!message.is_state_transition) {
            bins control_0 = {0};
            bins control_not_0 = {[1 : 2**rx_verification_pack::CONTROL_DATA_WIDTH-1]};
        }

        // number of errors in length+crc
        // Guard: sample normal packets AND MAYBE→NOT transition items (got_locked==0).
        //   - Normal packets:              is_state_transition==0  → sampled (0 or 1 errors)
        //   - MAYBE→NOT drop:             is_state_transition==1, got_locked==0 → sampled (always 2)
        //   - lock_achieved transition:    is_state_transition==1, got_locked==1 → excluded
        length_crc_errors: coverpoint message.num_errors_length_crc
            iff (!message.is_state_transition || (message.is_state_transition && !message.got_locked)) {
            bins zero_errors        = {0};
            bins one_error          = {1};
            bins two_or_more_errors = {2};
        }

        // number of errors in control+crc
        control_crc_errors: coverpoint message.num_errors_control_crc iff (!message.is_state_transition) {
            bins zero_errors = {0};
            bins one_error = {1};
        }

        // parity valid/not valid
        parity_validity: coverpoint message.parity_error iff (!message.is_state_transition) {
            bins valid = {0};
            bins invalid = {1};
        }

        // phase item (locked phase, 4-bit nibble so phase N == phase N+4)
        phase_item: coverpoint message.locked_phase iff (!message.is_state_transition) {
            bins phase_0 = {0, 4};
            bins phase_1 = {1, 5};
            bins phase_2 = {2, 6};
            bins phase_3 = {3, 7};
        }

        // lock valid threshold
        lock_threshold: coverpoint lock_valid_threshold_val {
            bins th[] = {[rx_verification_pack::MIN_LOCK_VALID_THRESHOLD : rx_verification_pack::MAX_LOCK_VALID_THRESHOLD]};
        }

        // Ten-transaction-sequence completion flag.
        // Coverage is met ONLY when the flag is 1 (>=10 valid MIN→4K→MID sequences seen).
        // When the flag is 0 the sample is IGNORED and does NOT affect coverage percentage.
        ten_transactions_done: coverpoint message.ten_transactions_done_flag iff (!message.is_state_transition) {
            bins         done   = {1}; // ← this is the ONLY bin that must be hit
            ignore_bins  not_done = {0}; // ← 0 is ignored; sampling it has zero effect
        }

        // ====== STATE TRANSITIONS ======
        lock_achieved: coverpoint message.got_locked iff (message.is_state_transition && message.got_locked == 1) {
            bins achieved = {1};
        }

        // Categorize dropped events in MAYBE_LOCKED: 
        // 1 -> Early drop, 2 -> Dropped exactly at LVT-1
        maybe_dropped_consecutive_count: coverpoint get_drop_category(message.consecutive_packets_dropped, lock_valid_threshold_val) 
        iff (message.is_state_transition && message.got_locked == 0 && message.consecutive_packets_dropped > 0) {
            bins went_out_of_maybe_to_not = {1};
            bins dropped_at_lvt_minus_1   = {2};
            ignore_bins ignored = {0};
        }

        cross_maybe_dropped_lvt: cross maybe_dropped_consecutive_count, lock_threshold {
            ignore_bins impossible_lvt2_early = binsof(lock_threshold) intersect {1, 2} && binsof(maybe_dropped_consecutive_count) intersect {1};
        }

        valid_prob: coverpoint valid_probability {
            bins p_1_ratio = {1};
            bins p_25_perc = {25};
            bins p_100_perc = {100};
        }
    endgroup


    /*------------------------------------------------------------------------------
    -- Coverage Helper Functions
    ------------------------------------------------------------------------------*/
    // Helper function to safely evaluate and categorize drops against lock thresholds
    function int get_drop_category(int drops, int lvt);
        if (drops == lvt - 1) begin
            return 2; // Dropped precisely at LVT-1
        end else if (drops > 0 && drops < lvt - 1) begin
            return 1; // Dropped early (between 1 and LVT-2)
        end else begin
            return 0; // Ignore / Invalid
        end
    endfunction

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
    // =============================================================================
    // Build Phase
    // -----------------------------------------------------------------------------
    // The UVM build_phase is executed top-down. It is responsible for retrieving
    // configuration objects from the UVM configuration database, computing local
    // configuration values, and instantiating lower-level UVM components.
    // =============================================================================
    virtual function void build_phase(uvm_phase phase);
        rx_generation_parameters parameters;
        super.build_phase(phase);
        if (!uvm_config_db #(int unsigned)::get(null, "*", "lock_valid_threshold_val", this.lock_valid_threshold_val)) begin
            `uvm_fatal(get_type_name(), "Couldn't find lock_valid_threshold_val in config_db")
        end
        if (uvm_config_db #(rx_generation_parameters)::get(this, "", "parameters", parameters)) begin
            this.valid_probability = parameters.INPUT_DATA_VALID_PROBABILITY;
        end else begin
            `uvm_error(get_type_name(), "Failed to get parameters from config_db, defaulting to 100")
            this.valid_probability = 100;
        end
    endfunction

    /*------------------------------------------------------------------------------
    -- Write Function (UVM Subscriber)
    ------------------------------------------------------------------------------*/
    virtual function void write(rx_coverage_item t);
        rx_cg.sample(t, lock_valid_threshold_val, valid_probability);
    endfunction
    
    // Kept for backwards compatibility if called directly
    virtual function void sample(rx_coverage_item message);
        rx_cg.sample(message, lock_valid_threshold_val, valid_probability);
    endfunction


endclass

`endif // __RX_COVERAGE
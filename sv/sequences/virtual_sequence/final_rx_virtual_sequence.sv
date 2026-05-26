////////////////////////////////////////////////////////////////////////////////
//
// File name    : final_rx_virtual_sequence.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Virtual sequence coordinating multiple physical sequences (input, configuration, parity) to emulate complex test scenarios.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_VIRTUAL_SEQUENCE
`define __RX_VIRTUAL_SEQUENCE

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
class rx_virtual_sequence extends uvm_sequence;

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_object_utils        (rx_virtual_sequence)
    `uvm_declare_p_sequencer (rx_virtual_sequencer) 

    /*------------------------------------------------------------------------------
    -- Parameters.
    ------------------------------------------------------------------------------*/
    rx_generation_parameters parameters = null;

    /*------------------------------------------------------------------------------
    -- Members.
    ------------------------------------------------------------------------------*/
    int unsigned        lock_valid_threshold_val;
    bit                 the_dut_is_locked;
    rand rx_test_type_e test_type; // Randomized stimulus field
    rand rx_lock_type_e lock_type; // Randomized stimulus field

    /*------------------------------------------------------------------------------
    -- Nested Sequences.
    ------------------------------------------------------------------------------*/
    rx_input_data_sequence input_data_sequence = null;
    
    // Decide if the test would simulate the real scenario or random.
    constraint test_type_c { // UVM Randomization constraint block
        test_type dist {
            TEST_REGULAR := this.parameters.RUN_RANDOM_TEST_P,
            TEST_REAL    := this.parameters.RUN_REAL_TEST_P
        };
    }


    constraint lock_type_c { // UVM Randomization constraint block
        lock_type dist {
            LOCK_REGULAR         := this.parameters.LOCK_REGULAR_TEST_P,
            LOCK_ONE_PACKET_OUT  := this.parameters.LOCK_ONE_PACKET_OUT_TEST_P,
            LOCK_PHASE_CHANGE    := this.parameters.LOCK_PHASE_CHANGE_TEST_P,
            LOCK_SINGLE_BIT_ERR  := this.parameters.LOCK_SINGLE_BIT_ERR_TEST_P, // NOT RELEVANT FOR NOW BECAUSE DUT DO NOT SUPPORT THIS.
            LOCK_MULTI_BIT_ERR   := this.parameters.LOCK_MULTI_BIT_ERR_TEST_P
        };
    }

    rand int unsigned num_msgs; // Randomized stimulus field
    constraint num_msgs_c { // UVM Randomization constraint block
        num_msgs inside {[this.parameters.MIN_MESSAGES_IN_REGULAR_TEST : this.parameters.MAX_MESSAGES_IN_REGULAR_TEST]};
    }


    rand int unsigned transaction_count; // Randomized stimulus field
    constraint transaction_count_c { // UVM Randomization constraint block
        transaction_count inside {[this.parameters.MIN_TRANSACTIONS_IN_REAL_TEST : this.parameters.MAX_TRANSACTIONS_IN_REAL_TEST]};
    }

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new(string name = "rx_virtual_sequence");
        super.new(name);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Pre start.
    -------------------------------------------------------------------------------*/
    task pre_start();

        // Raise objection
        if ((get_parent_sequence() == null) && (starting_phase != null)) begin
            starting_phase.raise_objection(this, "Starting");
        end 
    endtask

    /*------------------------------------------------------------------------------
    -- Pre randomize.
    ------------------------------------------------------------------------------*/
    function void pre_randomize();

        // Get the parameters from the test.
        if(!uvm_config_db #(rx_generation_parameters)::get(null, this.get_full_name(), "parameters", this.parameters)) begin
            `uvm_fatal(this.get_name().toupper(), "Couldn't find the generation parameters")
        end 

        // Get lock_valid_threshold_val
        if(!uvm_config_db #(int unsigned)::get(null, "*", "lock_valid_threshold_val", this.lock_valid_threshold_val)) begin
             `uvm_fatal(this.get_name().toupper(), "Couldn't find lock_valid_threshold_val")
        end 
    endfunction

    /*-------------------------------------------------------------------------------
    -- Body.
    -------------------------------------------------------------------------------*/
    task body();
        the_dut_is_locked = 0;
        `uvm_info(get_name(), $sformatf("Randomized: test_type=%s, lock_type=%s, num_msgs=%0d, transaction_count=%0d", test_type.name(), lock_type.name(), num_msgs, transaction_count), UVM_LOW)
        
        // Create Phase - sending junk before messages to create the phase in the messages
        // Controlled by parameters.SEND_PHASE_JUNK (default=1). Set to 0 to skip.
        if (parameters.SEND_PHASE_JUNK) begin
            `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                input_data.half_packet == 1; // Removes the header of the message so it would be junk data.
                input_data.length inside {[this.parameters.MIN_LENGTH_FOR_START_JUNK : this.parameters.MAX_LENGTH_FOR_START_JUNK]}; // Sending small messages.
            })
        end

        // Handle Lock Types
        case(lock_type)

            // The fastest way to lock the dut
            LOCK_REGULAR: begin
                `uvm_info(get_name(), "Executing LOCK_REGULAR scenario...", UVM_LOW)
                repeat(lock_valid_threshold_val) begin
                    if (test_type == TEST_REAL) begin
                        `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                            input_data.length == this.parameters.MIN_PACKET_LENGTH; // The real scenerio locks with minimum size messages.
                            input_data.half_packet == 0;
                            input_data.wrong_length == 0;
                        })
                    end else begin
                        `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                            input_data.half_packet == 0;
                            input_data.wrong_length == 0;
                        })
                    end
                end
                the_dut_is_locked = 1;
            end
            LOCK_ONE_PACKET_OUT: begin
                `uvm_info(get_name(), "Executing LOCK_ONE_PACKET_OUT scenario...", UVM_LOW)
                repeat(lock_valid_threshold_val) begin
                    `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                        input_data.half_packet == 0;
                        input_data.wrong_length == 0;
                    })
                end
                // Send a 1 packet with is_locked == 1 and length != MIN_DATA_SIZE
                `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                        is_locked == 1; 
                        input_data.length != this.parameters.MIN_PACKET_LENGTH;
                        input_data.half_packet == 0;
                        input_data.wrong_length == 0;
                    })
            end
            LOCK_PHASE_CHANGE: begin
                `uvm_info(get_name(), "Executing LOCK_PHASE_CHANGE scenario...", UVM_LOW)
                // 1 to LVT-1 packets
                repeat($urandom_range(1, lock_valid_threshold_val - 1)) begin
                     `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                        input_data.half_packet == 0;
                        input_data.length_error == 0;
                        input_data.wrong_length == 0;
                     })
                end
                
                // change phase
                `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                     input_data.half_packet == 1;
                })
                
                // LVT packets
                repeat(lock_valid_threshold_val) begin
                     `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                        input_data.half_packet == 0;
                        input_data.length_error == 0;
                        input_data.wrong_length == 0;
                     })
                end
                the_dut_is_locked = 1;
            end

            /*================================================
            NOT RELEVANT FOR NOW BECAUSE DUT NOT SUPPORT THIS
            ================================================*/

            LOCK_SINGLE_BIT_ERR: begin
                `uvm_info(get_name(), "Executing LOCK_SINGLE_BIT_ERR scenario...", UVM_LOW)
                // LVT-1 packets
                repeat(lock_valid_threshold_val - 1) begin
                     `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                        input_data.half_packet == 0;
                        input_data.length_error == 0;
                        input_data.wrong_length == 0;
                     })
                end
                
                // 1 packet with length_error
                `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                     input_data.length_error == 1;
                     input_data.half_packet == 0;
                     input_data.wrong_length == 0;
                })
                
                // LVT packets
                repeat(lock_valid_threshold_val) begin
                     `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                        input_data.half_packet == 0;
                        input_data.length_error == 0;
                        input_data.wrong_length == 0;
                     })
                end

            end

            
            LOCK_MULTI_BIT_ERR: begin
                `uvm_info(get_name(), "Executing LOCK_MULTI_BIT_ERR scenario...", UVM_LOW)
                // 1 to LVT-1 packets
                repeat($urandom_range(1, lock_valid_threshold_val - 1)) begin
                     `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                        input_data.half_packet == 0;
                        input_data.length_error == 0;
                        input_data.wrong_length == 0;
                     })
                end
                
                // Packet with wrong length
                `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                     input_data.wrong_length == 1;
                     input_data.half_packet == 0;
                })
                
                // LVT packets
                repeat(lock_valid_threshold_val) begin
                     `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                        input_data.half_packet == 0;
                        input_data.length_error == 0;
                        input_data.wrong_length == 0;
                     })
                end
                the_dut_is_locked = 1;
            end
        endcase

        // Handle Test Types
        case(test_type)
                TEST_REGULAR: begin
                    `uvm_info(get_name(), "Executing TEST_REGULAR scenario...", UVM_LOW)
                    if(the_dut_is_locked == 1) begin
                        if(lock_type!= LOCK_ONE_PACKET_OUT) begin
                            repeat(num_msgs) begin
                                `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                                    is_locked == 1;
                                    input_data.half_packet == 0;
                                    input_data.wrong_length == 0;
                                })
                            end
                        end
                    end
                end
                TEST_REAL: begin
                    `uvm_info(get_name(), "Executing TEST_REAL scenario...", UVM_LOW)
                    if(the_dut_is_locked == 1) begin
                        if(lock_type!= LOCK_ONE_PACKET_OUT) begin

                            int _tx_idx = 0;
                            repeat(transaction_count) begin
                                //==========================================================
                                //add counter to dont freeze the script in case of long transactions
                                //==========================================================
                                `uvm_info(get_name(), $sformatf("TEST_REAL: Starting transaction %0d / %0d", transaction_count - _tx_idx, transaction_count), UVM_LOW)
                                _tx_idx++;
                                // 0-1000 packets of min length
                                repeat($urandom_range(this.parameters.MIN_ZERO_PACKETS_IN_REAL_TEST, this.parameters.MAX_ZERO_PACKETS_IN_REAL_TEST)) begin

                                    `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                                    is_locked == 1;
                                    input_data.length == this.parameters.MIN_PACKET_LENGTH;
                                    input_data.half_packet == 0;
                                    input_data.wrong_length == 0;
                                })
                                end
                                // 0-100 optimal
                                repeat($urandom_range(this.parameters.MIN_OPTIMAL_PACKETS_IN_REAL_TEST, this.parameters.MAX_OPTIMAL_PACKETS_IN_REAL_TEST)) begin

                                    `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                                        is_locked == 1;
                                        input_data.length == this.parameters.OPTIMAL_PACKET_LENGTH;
                                        input_data.half_packet == 0;
                                        input_data.wrong_length == 0;
                                    })
                                    
                                end
                                // 1 that between min-optimal
                                `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                                    is_locked == 1;
                                    input_data.length inside {[this.parameters.MIN_PACKET_LENGTH + 1 : this.parameters.OPTIMAL_PACKET_LENGTH - 1]};
                                    input_data.half_packet == 0;
                                    input_data.wrong_length == 0;
                                })
                            end
                        end
                    end
                end
        endcase

        // ---- End-of-test garbage: send a half packet with corrupted length ----
        `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
            input_data.half_packet == 1;
            input_data.length == this.parameters.MIN_PACKET_LENGTH;
        })
    endtask

    /*-------------------------------------------------------------------------------
    -- Post start.
    -------------------------------------------------------------------------------*/
    task post_start();

        // Drop objection
        if ((get_parent_sequence() == null) && (starting_phase != null)) begin
            `uvm_info(get_name(), "Virtual sequence finished. Set watchdog to $finish in 10us.", UVM_LOW)
            starting_phase.drop_objection(this, "Ending");
        end
    endtask
endclass

`endif // __RX_VIRTUAL_SEQUENCE
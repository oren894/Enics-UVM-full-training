////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_virtual_sequence.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Virtual sequence of the module rx.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_VIRTUAL_SEQUENCE
`define __RX_VIRTUAL_SEQUENCE

import uvm_pkg::*;
`include "uvm_macros.svh"


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
    int unsigned lock_valid_threshold_val;
    /*------------------------------------------------------------------------------
    -- Nested Sequences.
    ------------------------------------------------------------------------------*/
    rx_input_data_sequence           input_data_sequence           = null;
    bit lock_valid;
    rand rx_test_type_e test_type;
    rand rx_lock_type_e lock_type;

    constraint test_type_c {
        test_type dist {
            TEST_REGULAR := 1,
            TEST_REAL    := 1
        };
    }

    constraint lock_type_c {
        lock_type dist {
            LOCK_REGULAR        := 1,
            LOCK_ONE_PACKET_OUT := 1,
            LOCK_PHASE_CHANGE   := 1,
            LOCK_HARD_NOT_LOCKED := 1,
            LOCK_SOFT_NOT_LOCKED := 1
        };
    }

    rand int unsigned num_msgs;
    constraint num_msgs_c {
        num_msgs inside {[10:100]};
    }


    rand int unsigned transaction_count;
    constraint transaction_count_c {
        transaction_count inside {[1:10]};
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
        lock_valid = 0;

        // Randomize the virtual sequence parameters (test_type, lock_type, etc.)
        if(!this.randomize()) begin
            `uvm_fatal(get_name(), "Failed to randomize virtual sequence!")
        end
        `uvm_info(get_name(), $sformatf("Randomized: test_type=%s, lock_type=%s, num_msgs=%0d, transaction_count=%0d", test_type.name(), lock_type.name(), num_msgs, transaction_count), UVM_LOW)
        $display("Randomized: test_type=%s, lock_type=%s, num_msgs=%0d ,transaction_count=%0d", test_type.name(), lock_type.name(), num_msgs, transaction_count);
        //Create Phase

            $display("Creating half packet");
            `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                input_data.half_packet == 1;
            })


        // Handle Lock Types
        case(lock_type)
            LOCK_REGULAR: begin
                `uvm_info(get_name(), "Executing LOCK_REGULAR scenario...", UVM_LOW)
                repeat(lock_valid_threshold_val) begin
                    if (test_type == TEST_REAL) begin
                        `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                            input_data.length == rx_verification_pack::MIN_DATA_SIZE;
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
                lock_valid = 1;
            end
            LOCK_ONE_PACKET_OUT: begin
                `uvm_info(get_name(), "Executing LOCK_ONE_PACKET_OUT scenario...", UVM_LOW)
                repeat(lock_valid_threshold_val) begin
                    `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                        input_data.half_packet == 0;
                        input_data.wrong_length == 0;
                    })
                end
                //send a 1 packet with is_locked == 1 and length != MIN_DATA_SIZE
                `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                        is_locked == 1; input_data.length != rx_verification_pack::MIN_DATA_SIZE;
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
                lock_valid = 1;
            end
            LOCK_HARD_NOT_LOCKED: begin
                `uvm_info(get_name(), "Executing LOCK_HARD_NOT_LOCKED scenario...", UVM_LOW)
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
            LOCK_SOFT_NOT_LOCKED: begin
                `uvm_info(get_name(), "Executing LOCK_SOFT_NOT_LOCKED scenario...", UVM_LOW)
                // 1 to LVT-1 packets
                repeat($urandom_range(1, lock_valid_threshold_val - 1)) begin
                     `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                        input_data.half_packet == 0;
                        input_data.length_error == 0;
                        input_data.wrong_length == 0;
                     })
                end
                
                // packet with wrong length
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
                lock_valid = 1;
            end
        endcase

        // Handle Test Types
        case(test_type)
            
                TEST_REGULAR: begin
                    `uvm_info(get_name(), "Executing TEST_REGULAR scenario...", UVM_LOW)
                    if(lock_valid == 1) begin
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
                    if(lock_valid == 1) begin
                        if(lock_type!= LOCK_ONE_PACKET_OUT) begin
                            repeat(transaction_count) begin
                                // 0-1000 packets of min length
                                repeat($urandom_range(0, 1000)) begin
                                    `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                                    is_locked == 1;
                                    input_data.length == rx_verification_pack::MIN_DATA_SIZE;
                                    input_data.half_packet == 0;
                                    input_data.wrong_length == 0;
                                })
                                end
                                // 0-100 optimal
                                repeat($urandom_range(0, 100)) begin
                                    `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                                        is_locked == 1;
                                        input_data.length == rx_verification_pack::OPTIMAL_DATA_SIZE;
                                        input_data.half_packet == 0;
                                        input_data.wrong_length == 0;
                                    })
                                end
                                // 1 that between min-optimal
                                `uvm_do_on_with(input_data_sequence, p_sequencer.input_data_sequencer, {
                                    is_locked == 1;
                                    input_data.length inside {[rx_verification_pack::MIN_DATA_SIZE + 1 : rx_verification_pack::OPTIMAL_DATA_SIZE - 1]};
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
        })
        
    endtask

    /*-------------------------------------------------------------------------------
    -- Post start.
    -------------------------------------------------------------------------------*/
    task post_start();

        // Drop objection
        if ((get_parent_sequence() == null) && (starting_phase != null)) begin
            starting_phase.drop_objection(this, "Ending");
        end
    endtask
endclass

`endif // __RX_VIRTUAL_SEQUENCE
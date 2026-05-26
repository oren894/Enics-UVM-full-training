////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_input_data_sequence.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Base sequence responsible for generating and driving randomized packet items into the RX module with configurable error injection.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_INPUT_DATA_SEQUENCE
`define __RX_INPUT_DATA_SEQUENCE

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
class rx_input_data_sequence extends uvm_sequence #(dv_sequence_item #(rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH));

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_object_utils        (rx_input_data_sequence)
    `uvm_declare_p_sequencer (dv_sequencer #(rx_verification_pack::INPUT_DATA_WIDTH, rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH))

    /*------------------------------------------------------------------------------
    -- Parameters.
    ------------------------------------------------------------------------------*/
    rx_generation_parameters parameters;

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    rand rx_item input_data; // Randomized stimulus field
    static bit remainder[$]; // Buffer for leftover bits from previous items 
    rand bit is_locked; // Randomized stimulus field
    rand bit is_wrong_length; // Randomized stimulus field

    /*-------------------------------------------------------------------------------
    -- Constraints
    -------------------------------------------------------------------------------*/
    constraint length_c { // UVM Randomization constraint block
        // Length will be randomized between MIN-MAX and divisible by 4
        input_data.length inside {[rx_verification_pack::MIN_DATA_SIZE:rx_verification_pack::MAX_DATA_SIZE]};
        input_data.length % 4 == 0;
    }

    //need to have constraint only for the virtual sequence that send the data 
    constraint half_packet_c { // UVM Randomization constraint block
        input_data.half_packet dist {
            0 := 99,
            1 := 1
        };
    }

    constraint control_c { // UVM Randomization constraint block
        input_data.control dist {
            0             := this.parameters.CONTROL_ZERO_P,
            [1:$]         := 100 - this.parameters.CONTROL_ZERO_P
        };
    }

    constraint length_error_c { // UVM Randomization constraint block
        if (is_locked) {
            input_data.length_error dist {
                0 := 100 - this.parameters.LENGTH_ERROR_P,
                1 := this.parameters.LENGTH_ERROR_P
            };
        } else {
            input_data.length_error == 0;
        }
    }

    constraint wrong_length_c { // UVM Randomization constraint block
        if (is_wrong_length) {
            input_data.wrong_length == 1;
        } else {
            input_data.wrong_length == 0;
        }
    }

    constraint control_error_c { // UVM Randomization constraint block
        input_data.control_error dist {
            0 := 100 - this.parameters.CONTROL_ERROR_P,
            1 := this.parameters.CONTROL_ERROR_P
        };
    }   

    constraint parity_error_c { // UVM Randomization constraint block
        input_data.parity_error dist {
            0 := 100 - this.parameters.PARITY_ERROR_P,
            1 := this.parameters.PARITY_ERROR_P
        };
    }
    /*-------------------------------------------------------------------------------
    -- Constructor
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_input_data_sequence");
        super.new (name);

        // Initialize members
        this.input_data = rx_item ::type_id::create("input_data");
        // `uvm_create(super.req)
    endfunction

    /*-------------------------------------------------------------------------------
    -- Pre start
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

        // Get the parameters from the test
        if(!uvm_config_db #(rx_generation_parameters)::get(null, this.get_full_name(), "parameters", this.parameters)) begin
            `uvm_fatal(this.get_name().toupper(), "Couldn't find the generation parameters")
        end

        // Update the parameters in the item
        this.input_data.parameters = this.parameters;
    endfunction

    /*-------------------------------------------------------------------------------
    -- Body
    -------------------------------------------------------------------------------*/
    task body();
        bit bit_array[];
        bit bit_queue[$];
        bit [rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH-1:0] chunk_data;
        int start_idx = 0;

        // 1. Pack the item into a bit array
        this.input_data.pack(bit_array);
        // 2. Handle Half Packet: Strip Headers and Random Data
        if (this.input_data.half_packet) begin
            int header_bits = rx_verification_pack::LENGTH_DATA_WIDTH + 
                              rx_verification_pack::LENGTH_CRC_DATA_WIDTH + 
                              rx_verification_pack::CONTROL_DATA_WIDTH + 
                              rx_verification_pack::CONTROL_CRC_DATA_WIDTH;
            
            // Strip headers + 1 to 7 extra bits to force byte/chunk misalignment
            int random_strip = $urandom_range(1, 7);

            if ((header_bits + random_strip) < bit_array.size()) begin
                start_idx = header_bits + random_strip;
            end else begin
                // If the packet is abnormally small, skip pushing anything
                start_idx = bit_array.size(); 
            end
        end

        // 3. Prepend remainder from previous transactions FIRST
        foreach(remainder[i]) begin
            bit_queue.push_back(remainder[i]);
        end
        remainder.delete(); // Clear the static buffer after copying

        // 4. Append the current packed data starting from start_idx
        for(int i = start_idx; i < bit_array.size(); i++) begin
            bit_queue.push_back(bit_array[i]);
        end

        // 5. Send full chunks
        while (bit_queue.size() >= rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH) begin
            // Extract chunk (assuming pop_front() represents MSB to LSB as per your original loop)
            for (int i = rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH-1; i >= 0; i--) begin
                 chunk_data[i] = bit_queue.pop_front();
            end
            
            // Send to sequencer
            `uvm_do_on_with(this.req, this.p_sequencer, {data == chunk_data;}) 
        end

        // 6. Save leftover bits back to the static variable for the next sequence execution
        remainder = bit_queue;
    endtask

    /*-------------------------------------------------------------------------------
    -- Post start
    -------------------------------------------------------------------------------*/
    task post_start();

        // Drop objection
        if ((get_parent_sequence() == null) && (starting_phase != null)) begin
            starting_phase.drop_objection(this, "Ending");
        end
    endtask
endclass

`endif // __RX_INPUT_DATA_SEQUENCE
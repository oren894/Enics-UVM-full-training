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
// Description: Simplified base sequence for the basic exercise test.
//              Sends clean packets only — no error injection, no half packets,
//              no remainder buffer (no phase junk to misalign).
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

    /*-------------------------------------------------------------------------------
    -- Constraints
    -------------------------------------------------------------------------------*/
    constraint length_c { // UVM Randomization constraint block
        // Length will be randomized between MIN-MAX and divisible by 4
        input_data.length inside {[rx_verification_pack::MIN_DATA_SIZE:rx_verification_pack::MAX_DATA_SIZE]};
        input_data.length % 4 == 0;
    }

    constraint control_c { // UVM Randomization constraint block
        input_data.control dist {
            0             := this.parameters.CONTROL_ZERO_P,
            [1:$]         := 100 - this.parameters.CONTROL_ZERO_P
        };
    }

    /*-------------------------------------------------------------------------------
    -- Constructor
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_input_data_sequence");
        super.new (name);

        // Initialize members
        this.input_data = rx_item ::type_id::create("input_data");
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
    -- Packs the item into a bit array and sends it as 8-bit chunks.
    -- No remainder buffer needed (no junk/phase, packets are byte-aligned).
    -------------------------------------------------------------------------------*/
    task body();
        bit bit_array[];
        bit bit_queue[$];
        bit [rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH-1:0] chunk_data;

        // 1. Pack the item into a bit array
        this.input_data.pack(bit_array);

        // 2. Copy all bits into a queue
        for(int i = 0; i < bit_array.size(); i++) begin
            bit_queue.push_back(bit_array[i]);
        end

        // 3. Send full chunks (8 bits at a time)
        while (bit_queue.size() >= rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH) begin
            for (int i = rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH-1; i >= 0; i--) begin
                 chunk_data[i] = bit_queue.pop_front();
            end
            
            // Send to sequencer
            `uvm_do_on_with(this.req, this.p_sequencer, {data == chunk_data;}) 
        end
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

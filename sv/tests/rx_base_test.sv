////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_base_test.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Base test for the module rx.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_BASE_TEST
`define __RX_BASE_TEST

import uvm_pkg::*;
`include "uvm_macros.svh"

class rx_base_test extends uvm_test;

    /*------------------------------------------------------------------------------
    -- UVM Macros.
    ------------------------------------------------------------------------------*/
    `uvm_component_utils (rx_base_test) 

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    rx_environment           environment = null;
    rx_generation_parameters parameters  = null;

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_base_test", uvm_component parent = null);
        super.new (name, parent);
    endfunction

    /*------------------------------------------------------------------------------
    -- Build Phase.
    ------------------------------------------------------------------------------*/
    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        
        // Printing the hierarchy
        uvm_root::get().enable_print_topology = rx_verification_pack::TOPOLOGY;

        // Create environment
        this.environment = rx_environment::type_id::create("environment", this); 

        // Set generation parameters
        this.parameters = new("parameters");
        uvm_config_db #(rx_generation_parameters)::set(this, "*", "parameters", this.parameters);

        // Set the agents configuration
        uvm_config_db #(int)::set(this, "environment.input_data_agent.driver",    "valid_probability", parameters.INPUT_DATA_VALID_PROBABILITY);
        uvm_config_db #(int)::set(this, "environment.input_data_agent",           "is_active",         UVM_ACTIVE);
        uvm_config_db #(int)::set(this, "environment.output_data_agent",          "is_active",         UVM_ACTIVE);
        uvm_config_db #(int)::set(this, "environment.control_agent",              "is_active",         UVM_ACTIVE);
        uvm_config_db #(bit)::set(this, "environment.input_data_agent*",           "is_master",         1'b1);
        uvm_config_db #(bit)::set(this, "environment.output_data_agent*",          "is_master",         1'b0);
        uvm_config_db #(bit)::set(this, "environment.control_agent*",              "is_master",         1'b0);

        $display("hiiii, ", this.get_full_name());
    endfunction

    /*-------------------------------------------------------------------------------
    -- Connect Phase
    -------------------------------------------------------------------------------*/
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Set the sequence as the default sequence of the sequencer in main_phase
        uvm_config_db#(uvm_object_wrapper)::set(
            this.environment,
            "virtual_sequencer.main_phase",
            "default_sequence",
            rx_virtual_sequence::type_id::get()
        );
    endfunction
endclass

`endif // __RX_BASE_TEST
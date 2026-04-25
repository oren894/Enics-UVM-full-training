////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_base_test.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Base UVM test class providing the foundation for all RX tests, configuring the environment and initiating the virtual sequence.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_BASE_TEST
`define __RX_BASE_TEST

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
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
    // =============================================================================
    // Build Phase
    // -----------------------------------------------------------------------------
    // The UVM build_phase is executed top-down. It is responsible for retrieving
    // configuration objects from the UVM configuration database, computing local
    // configuration values, and instantiating lower-level UVM components.
    // =============================================================================
    virtual function void build_phase (uvm_phase phase);
        rx_report_server srv;
        super.build_phase(phase);
        
        // Instantiate and apply custom report server for end-of-sim banners
        srv = new();
        uvm_report_server::set_server(srv);
        

        // Printing the hierarchy
        uvm_root::get().enable_print_topology = rx_verification_pack::TOPOLOGY;

        // Create environment
        this.environment = rx_environment::type_id::create("environment", this); 

        // Set generation parameters
        this.parameters = new("parameters");
        if (!this.parameters.randomize() with {
            // 1   = Deterministic 1:4 (1-0-0-0 pattern)
            // 25  = Probabilistic 25% valid per cycle
            // 100 = Constant 1 (Always valid)
            INPUT_DATA_VALID_PROBABILITY dist {
                1   := INPUT_DATA_VALID_1_TO_4_RATIO_P,
                25  := INPUT_DATA_VALID_25_PERCENT_P,
                100 := INPUT_DATA_VALID_100_PERCENT_P
            };
        }) begin
            `uvm_fatal(this.get_full_name(), "Failed to randomize parameters")
        end
        uvm_config_db #(rx_generation_parameters)::set(this, "*", "parameters", this.parameters);

        // Set the agents configuration
        uvm_config_db #(int)::set(this, "environment.input_data_agent.driver",    "valid_probability", parameters.INPUT_DATA_VALID_PROBABILITY);
        uvm_config_db #(int)::set(this, "environment.input_data_agent",           "is_active",         UVM_ACTIVE);
        uvm_config_db #(int)::set(this, "environment.output_data_agent",          "is_active",         UVM_ACTIVE);
        uvm_config_db #(int)::set(this, "environment.control_agent",              "is_active",         UVM_ACTIVE);
        uvm_config_db #(int)::set(this, "environment.parity_agent",               "is_active",         UVM_ACTIVE);
        uvm_config_db #(bit)::set(this, "environment.input_data_agent*",          "is_master",         1'b1);
        uvm_config_db #(bit)::set(this, "environment.output_data_agent*",         "is_master",         1'b0);
        uvm_config_db #(bit)::set(this, "environment.control_agent*",             "is_master",         1'b0);
        uvm_config_db #(bit)::set(this, "environment.parity_agent*",              "is_master",         1'b0);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Connect Phase
    -------------------------------------------------------------------------------*/
    // =============================================================================
    // Connect Phase
    // -----------------------------------------------------------------------------
    // The connect_phase executes bottom-up. It is used to wire up the environment
    // by linking TLM analysis ports to their corresponding analysis exports, ensuring
    // proper data flow from monitors/agents to the scoreboard and coverage modules.
    // =============================================================================
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
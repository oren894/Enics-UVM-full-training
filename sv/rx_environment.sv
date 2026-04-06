////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_environment.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Verification environment for the project rx.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_ENVIRONMENT
`define __RX_ENVIRONMENT

import uvm_pkg::*;

`include "uvm_macros.svh"

class rx_environment extends uvm_env;

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_component_utils(rx_environment)

    /*-----------------------------------------------------------------------------------
    -- Members.
    -----------------------------------------------------------------------------------*/
    rx_input_data_agent           input_data_agent = null;
    rx_output_data_agent          output_data_agent = null;
    rx_control_agent              control_agent = null;
    rx_virtual_sequencer          virtual_sequencer = null;
    rx_reference_model            reference_model = null;
    rx_output_data_scoreboard     output_data_scoreboard = null;
    rx_control_scoreboard         control_scoreboard = null;
    rx_parity_agent               parity_agent = null;
    rx_parity_scoreboard          parity_scoreboard = null;
    rx_coverage                   coverage_subscriber = null;

    /*-----------------------------------------------------------------------------------
    -- Constructor.
    -----------------------------------------------------------------------------------*/
    function new (string name = "rx_environment", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    /*-----------------------------------------------------------------------------------
    -- Build Phase.
    -----------------------------------------------------------------------------------*/
    function void build_phase (uvm_phase phase);
        super.build_phase(phase);

        // Create reference model and scoreboard
        this.input_data_agent           = rx_input_data_agent           ::type_id::create("input_data_agent",           this);
        $display(" created agent: , ", this.input_data_agent.get_full_name());
        this.output_data_agent          = rx_output_data_agent          ::type_id::create("output_data_agent",          this);
        $display(" created agent: , ", this.output_data_agent.get_full_name());
        this.control_agent              = rx_control_agent              ::type_id::create("control_agent",              this);
        $display(" created agent: , ", this.control_agent.get_full_name());
        this.parity_agent               = rx_parity_agent               ::type_id::create("parity_agent",               this);
        $display(" created agent: , ", this.parity_agent.get_full_name());
        this.virtual_sequencer          = rx_virtual_sequencer          ::type_id::create("virtual_sequencer",          this);
        this.reference_model            = rx_reference_model            ::type_id::create("reference_model",            this);
        this.output_data_scoreboard     = rx_output_data_scoreboard     ::type_id::create("output_data_scoreboard",     this);
        this.control_scoreboard         = rx_control_scoreboard         ::type_id::create("control_scoreboard",         this);
        this.parity_scoreboard          = rx_parity_scoreboard          ::type_id::create("parity_scoreboard",          this);
        this.coverage_subscriber        = rx_coverage                   ::type_id::create("coverage_subscriber",        this);
        
    endfunction

    /*-----------------------------------------------------------------------------------
    -- Connect Phase.
    -----------------------------------------------------------------------------------*/
    function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);

        // Connect the virtual sequencer
        this.virtual_sequencer.input_data_sequencer           = this.input_data_agent.sequencer;

        // Connect the input agents to the reference model
        this.input_data_agent.data_export.connect(this.reference_model.input_data_port);

        // Connect the reference model to the scoreboards
        this.reference_model.output_data_export.connect(this.output_data_scoreboard.env_port);
        this.reference_model.control_export.connect(this.control_scoreboard.env_port);
        this.reference_model.parity_export.connect(this.parity_scoreboard.env_port);
        this.reference_model.coverage_export.connect(this.coverage_subscriber.analysis_export);

        // Connect the output agents to the scoreboarda
        this.output_data_agent.data_export.connect(this.output_data_scoreboard.dut_port);
        this.control_agent.data_export.connect(this.control_scoreboard.dut_port);
        this.parity_agent.data_export.connect(this.parity_scoreboard.dut_port);
    endfunction
endclass

`endif // __RX_ENVIRONMENT
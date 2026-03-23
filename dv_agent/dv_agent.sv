////////////////////////////////////////////////////////////////////////////////
//
// File name    : dv_agent.sv
// Project name : 
// Author       : 
// Date Created : 25/12
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Agent component for interaction with the DV interface.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __DV_AGENT
`define __DV_AGENT

import uvm_pkg::*;
`include "uvm_macros.svh"

class dv_agent #(
    parameter int  DATA_WIDTH = 4,
    parameter int  SEQUENCE_ITEM_WIDTH = DATA_WIDTH
) extends uvm_agent;

    /*-------------------------------------------------------------------------------
    -- UVM Macros.
    -------------------------------------------------------------------------------*/
    `uvm_component_param_utils(dv_agent #(DATA_WIDTH, SEQUENCE_ITEM_WIDTH))

    /*-------------------------------------------------------------------------------
    -- Ports.
    -------------------------------------------------------------------------------*/
    uvm_analysis_port #(dv_monitor_item#(SEQUENCE_ITEM_WIDTH)) data_export;

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    dv_driver    #(DATA_WIDTH, SEQUENCE_ITEM_WIDTH) driver;
    dv_monitor   #(DATA_WIDTH, SEQUENCE_ITEM_WIDTH) monitor;
    dv_sequencer #(DATA_WIDTH, SEQUENCE_ITEM_WIDTH) sequencer;

    bit is_master = 1'b0;

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "dv_agent", uvm_component parent = null);
        super.new(name, parent);

        // Initialize members
        this.data_export = null;
        this.driver      = null;
        this.monitor     = null;
        this.sequencer   = null;
    endfunction

    /*-------------------------------------------------------------------------------
    -- Build Phase
    -------------------------------------------------------------------------------*/
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Instantiate port
        this.data_export = new("data_export", this);

        // Create the monitor
        this.monitor = dv_monitor #(DATA_WIDTH, SEQUENCE_ITEM_WIDTH) ::type_id::create("monitor", this);

        // Get if master
        if(!uvm_config_db #(bit)::get(this, "", "is_master", is_master)) begin
            `uvm_fatal(this.get_full_name(), "Did not find is_master");
        end 

        $display("agent: , ", this.get_full_name());

        // Instantiate the components if the agent is active
        if(this.is_master) begin

            // Create the driver and the sequencer
            this.driver    = dv_driver    #(DATA_WIDTH, SEQUENCE_ITEM_WIDTH)::type_id::create("driver",    this);
            this.sequencer = dv_sequencer #(DATA_WIDTH, SEQUENCE_ITEM_WIDTH)::type_id::create("sequencer", this);
        end
    endfunction

    /*-------------------------------------------------------------------------------
    -- Connect Phase
    -------------------------------------------------------------------------------*/
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect the sequencer to the driver
        if(this.is_master) begin
            this.driver.seq_item_port.connect(sequencer.seq_item_export);
        end

        // Connect the monitor to the data export.
        this.monitor.data_export.connect(this.data_export); 
    endfunction
endclass

`endif // __DV_AGENT
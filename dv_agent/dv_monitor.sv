////////////////////////////////////////////////////////////////////////////////
//
// File name    : dv_monitor.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Monitor for dv interface.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __DV_MONITOR
`define __DV_MONITOR

import uvm_pkg::*;
`include "uvm_macros.svh"

class dv_monitor #(parameter int DATA_WIDTH = 4, parameter int SEQUENCE_ITEM_WIDTH = DATA_WIDTH) extends uvm_monitor;

    // Register this class with UVM Factory
    `uvm_component_param_utils(dv_monitor #(DATA_WIDTH, SEQUENCE_ITEM_WIDTH))

    /*-------------------------------------------------------------------------------
    -- Ports.
    -------------------------------------------------------------------------------*/
    uvm_analysis_port #(dv_monitor_item #(SEQUENCE_ITEM_WIDTH)) data_export;

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    virtual dv_if #(DATA_WIDTH) vif;

    // Number of chunks
    localparam int NUM_CHUNKS = SEQUENCE_ITEM_WIDTH / DATA_WIDTH;

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "dv_monitor", uvm_component parent = null);
        super.new(name, parent);

        // Initialize the components
        this.data_export = null;
    endfunction

    /*-------------------------------------------------------------------------------
    -- Build Phase.
    -------------------------------------------------------------------------------*/
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (SEQUENCE_ITEM_WIDTH % DATA_WIDTH != 0) begin
            `uvm_fatal("CFG_ERR", $sformatf("SEQUENCE_ITEM_WIDTH (%0d) must be divisible by DATA_WIDTH (%0d)", 
                                            SEQUENCE_ITEM_WIDTH, DATA_WIDTH))
        end

        // Get the mster interface from config_db
        if(!uvm_config_db #(virtual dv_if#(DATA_WIDTH))::get(this, "", "vif", this.vif)) begin
            `uvm_fatal(this.get_full_name(), "Did not find vif");
        end

        // Create port
        this.data_export = new ("data_export", this);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Run Phase
    -------------------------------------------------------------------------------*/
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        // Parse dv interface.
        monitors_interface();
    endtask

    /*-------------------------------------------------------------------------------
    -- Parse the data passed on the virtual interface to logical data.
    -------------------------------------------------------------------------------*/
    task monitors_interface();
        dv_monitor_item #(SEQUENCE_ITEM_WIDTH) monitor_item;

        // Monitor the interface for packets
        forever begin
            int i = NUM_CHUNKS - 1;
            // Create a new packet
            monitor_item = dv_monitor_item #(SEQUENCE_ITEM_WIDTH) ::type_id::create("monitor_item", this); 

            // The loop below handles waiting for valid data. 
            // We should NOT blindly wait a clock cycle here, as it will cause to skip 
            // the first byte of a back-to-back transfer!
            while ( i >= 0) begin
                // Wait for valid
                while (!vif.monitor_cb.valid) begin
                    @ (this.vif.monitor_cb);
                end
                
                // Save the data 
                monitor_item.data[i*DATA_WIDTH +: DATA_WIDTH] = vif.monitor_cb.data;
                if (i == 0) begin
                    $display("monitor_item.data = %h", monitor_item.data);
                end
                // if(vif.monitor_cb.valid)
                    i--;                    
                // Wait for the next cycle
                @ (this.vif.monitor_cb);
            end

            // Write the item out
            this.data_export.write(monitor_item);
        end
    endtask
endclass

`endif // __DV_MONITOR
////////////////////////////////////////////////////////////////////////////////
//
// File name    : dv_driver.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : ENICS
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: The driver interacts directly with the interface and set the
//              signals values.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __DV_DRIVER
`define __DV_DRIVER

import uvm_pkg::*;
`include "uvm_macros.svh"

class dv_driver #(parameter int DATA_WIDTH = 4, parameter int SEQUENCE_ITEM_WIDTH = DATA_WIDTH) extends uvm_driver #(dv_sequence_item #(SEQUENCE_ITEM_WIDTH));

    /*-------------------------------------------------------------------------------
    -- UVM Macros.
    -------------------------------------------------------------------------------*/
    `uvm_component_param_utils(dv_driver #(DATA_WIDTH, SEQUENCE_ITEM_WIDTH))

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    virtual dv_if #(DATA_WIDTH) vif;

    // Clock event
    event posedge_clk;

    // Number of chunks
    localparam int NUM_CHUNKS = SEQUENCE_ITEM_WIDTH / DATA_WIDTH;
    /*------------------------------------------------------------------------------
    -- Configuration.
    ------------------------------------------------------------------------------*/
    int valid_probability;

    /*-------------------------------------------------------------------------------
    -- Constructor
    -------------------------------------------------------------------------------*/
    function new (string name = "dv_driver", uvm_component parent = null);
        super.new(name, parent);

        // Initialize members
        this.vif                = null;
        this.valid_probability  = 25;
    endfunction

    /*-------------------------------------------------------------------------------
    -- Build Phase
    -------------------------------------------------------------------------------*/
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        

        if (SEQUENCE_ITEM_WIDTH % DATA_WIDTH != 0) begin
            `uvm_fatal("CFG_ERR", $sformatf("SEQUENCE_ITEM_WIDTH (%0d) must be divisible by DATA_WIDTH (%0d)", 
                                            SEQUENCE_ITEM_WIDTH, DATA_WIDTH))
        end
        // Connect the driver to the interface.
        if(!uvm_config_db #(virtual dv_if#(DATA_WIDTH))::get(this, "", "vif", this.vif)) begin
            `uvm_fatal(this.get_full_name(), "Did not find vif");
        end
    endfunction

    /*-------------------------------------------------------------------------------
    -- Connect Phase
    -------------------------------------------------------------------------------*/
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Get the valid probability from config_db, if null then fatal
        if(!uvm_config_db #(int)::get(this, "", "valid_probability", valid_probability)) begin
            `uvm_fatal(this.get_full_name(), "Did not find valid_probability");
        end 
    endfunction

    /*-------------------------------------------------------------------------------
    -- Run Phase
    -------------------------------------------------------------------------------*/
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        // Clear master.
        this.vif.CLEAR_MASTER_CB();
        @(this.vif.master_cb);

        fork 
            // The driver would always be master.
            this.drive_master();

            // Trigger posedge_clk.
            forever begin 
                @(this.vif.master_cb);
                ->this.posedge_clk;
            end
        join_none
    endtask

    /*-------------------------------------------------------------------------------
    -- Drive packets to the interface
    -------------------------------------------------------------------------------*/
    task drive_master();
        bit valid_bit = 0;
        int cycle_count = 0;

        // Driver infinite loop
        forever begin
            int i = NUM_CHUNKS - 1;

            // Clear master.
            this.vif.master_cb.valid <= 1'b0;
            this.vif.master_cb.data  <= '0;

            // Wait for the next item (req) from the sequencer
            this.seq_item_port.get_next_item(super.req);

            // Synchronize with the sequencer
            wait(this.posedge_clk.triggered);

            // While there are data chunks to send.
            
            while ( i >= 0) begin
                // $display("drive_master: i = %0d", i);
                // $display("message = %h", super.req.data);
                // $display("at time %0t", $time);
                

                    if (valid_probability == 1) begin
                        valid_bit = (cycle_count % 4 == 0) ? 1'b1 : 1'b0;
                        cycle_count++;
                    end else begin
                        // Random the valid signal to drive
                        std::randomize(valid_bit) with {
                            valid_bit dist {
                                0 :/ 100 - valid_probability,
                                1 :/ valid_probability
                            };
                        };
                    end
                    this.vif.master_cb.valid <= valid_bit;
                    
                    if (valid_bit) begin
                        this.vif.master_cb.data  <= super.req.data[i*DATA_WIDTH +: DATA_WIDTH];
                        i = i - 1;
                    end 

                    // Wait 1 cycle to synchronize.
                    @ (this.vif.master_cb);

                    // Clear signals.
                    this.vif.CLEAR_MASTER_CB();
                
            end
            // Inform the sequencer that the item has been driven.
            this.seq_item_port.item_done();
        end
    endtask
endclass

`endif // __DV_DRIVER
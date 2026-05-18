////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_scoreboard.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: UVM scoreboard comparing observed output transactions from the RX DUT against predicted transactions from the reference model.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_SCOREBOARD
`define __RX_SCOREBOARD

import uvm_pkg::*;

`include "uvm_macros.svh"

/*-------------------------------------------------------------------------------
-- Port Declaration.
-------------------------------------------------------------------------------*/ 

`uvm_analysis_imp_decl(_env)
`uvm_analysis_imp_decl(_dut)

class rx_scoreboard #(parameter int DATA_WIDTH = 4) extends uvm_scoreboard;

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_component_param_utils(rx_scoreboard #(DATA_WIDTH))

    /*-- Ports --------------------------------------------------------------------*/
    uvm_analysis_imp_env #(dv_monitor_item #(DATA_WIDTH), rx_scoreboard #(DATA_WIDTH)) env_port = null; // Inbound TLM analysis export for receiving transactions
    uvm_analysis_imp_dut #(dv_monitor_item #(DATA_WIDTH), rx_scoreboard #(DATA_WIDTH)) dut_port = null; // Inbound TLM analysis export for receiving transactions

    /*------------------------------------------------------------------------------
    -- Members.
    ------------------------------------------------------------------------------*/
    dv_monitor_item #(DATA_WIDTH) env_items[$]  = {};
    dv_monitor_item #(DATA_WIDTH) dut_items[$]  = {};
    int                           item_compared = 0; 

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_scoreboard", uvm_component parent = null);
        super.new (name, parent);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Write Environment.
    -------------------------------------------------------------------------------*/
    virtual function void write_env (dv_monitor_item #(DATA_WIDTH) item);

        // Push the item to the queue
        this.env_items.push_back(item);

        // `uvm_info(this.get_full_name(), $sformatf(" Write env"), UVM_LOW)
        // item.print();

        // Try to compare the items
        void'(this.compare());
    endfunction

    /*-------------------------------------------------------------------------------
    -- Write DUT.
    -------------------------------------------------------------------------------*/
    virtual function void write_dut (dv_monitor_item #(DATA_WIDTH) item);

        // Push the item to the queue
        this.dut_items.push_back(item);

        // `uvm_info(this.get_full_name(), $sformatf(" Write dut"), UVM_LOW)
        // item.print();

        // Try to compare the items
        void'(this.compare());
    endfunction


    /*-------------------------------------------------------------------------------
    -- Compare Items
    -------------------------------------------------------------------------------*/
    virtual function compare(); 
        dv_monitor_item #(DATA_WIDTH) env_item;
        dv_monitor_item #(DATA_WIDTH) dut_item;

        // If both queues are not empty
        if(this.env_items.size() > 0 && this.dut_items.size() > 0) begin

            // Get items from queue
            env_item = this.env_items.pop_front();
            dut_item = this.dut_items.pop_front();

            // Compare the items
            if(env_item.compare(dut_item)) begin
                this.item_compared++;
            //    `uvm_info(this.get_full_name(), $sformatf("%0d Items compare succeeded", this.item_compared), UVM_LOW)

            // If the items are not the same, print them and raise a fatal
            end else begin
                env_item.print();
                dut_item.print();
                `uvm_fatal(this.get_full_name(), $sformatf("--------------------Misscompare-------------------- the number of items compared before %0d", this.item_compared));
            end
        end
    endfunction

    /*-------------------------------------------------------------------------------
    -- Phase Ready To End
    -------------------------------------------------------------------------------*/
    virtual function void phase_ready_to_end(uvm_phase phase); 

        // Check if there are items left in the queues.
        if(this.env_items.size() != 0 || this.dut_items.size() != 0) begin
            phase.raise_objection(this);

            // Fork to allow delay
            fork
                begin

                    // Wait until there are no more items to compare
                    wait(this.env_items.size() == 0 && this.dut_items.size() == 0);

                    // Drop objection
                    phase.drop_objection(this);
                end
            join_none
        end
    endfunction

    /*-------------------------------------------------------------------------------
    -- Build Phase
    -------------------------------------------------------------------------------*/
    // =============================================================================
    // Build Phase
    // -----------------------------------------------------------------------------
    // The UVM build_phase is executed top-down. It is responsible for retrieving
    // configuration objects from the UVM configuration database, computing local
    // configuration values, and instantiating lower-level UVM components.
    // =============================================================================
    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);

        // Create the ports
        this.env_port = new("env_port", this);
        this.dut_port = new("dut_port", this);
    endfunction
endclass

`endif // __RX_SCOREBOARD
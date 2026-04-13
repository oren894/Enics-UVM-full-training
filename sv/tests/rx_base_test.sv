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

class rx_report_server extends uvm_report_server;

    int custom_id_count[string];

    // Intercept messages to safely build our own accessible ID database
    virtual function void process_report(
        uvm_severity severity,
        string name,
        string id,
        string message,
        uvm_action action,
        UVM_FILE file,
        string filename,
        int line,
        string composed_message,
        int verbosity_level,
        uvm_report_object client
        );
        
        if (custom_id_count.exists(id)) begin
            custom_id_count[id]++;
        end else begin
            custom_id_count[id] = 1;
        end
        
        super.process_report(severity, name, id, message, action, file, filename, line, composed_message, verbosity_level, client);
    endfunction

    virtual function void summarize(UVM_FILE file = 0);
        int err_count;
        int fatal_count;
        string banner;
        string output_str;

        uvm_report_catcher::summarize_report_catcher(file);

        err_count = this.get_severity_count(UVM_ERROR);
        fatal_count = this.get_severity_count(UVM_FATAL);

        banner = "\n";
        banner = {banner, "  +-----------------------------------------------------------+\n"};
        banner = {banner, "  |                >>> UVM REPORT SUMMARY <<<                 |\n"};
        banner = {banner, "  +-----------------------------------------------------------+\n"};

        banner = {banner, "  [ SEVERITY COUNTS ]\n"};
        banner = {banner, "  -------------------------------------------------------------\n"};
        
        for(uvm_severity_type s = s.first(); 1; s = s.next()) begin
            int cnt = this.get_severity_count(s);
            $sformat(output_str, "   * %-15s : %6d\n", s.name(), cnt);
            banner = {banner, output_str};
            if(s == s.last()) break;
        end

        banner = {banner, "  -------------------------------------------------------------\n"};
        banner = {banner, "  [ ID COUNTS ]\n"};
        banner = {banner, "  -------------------------------------------------------------\n"};
        
        foreach (custom_id_count[id]) begin
            int cnt = custom_id_count[id];
            $sformat(output_str, "   * [%-40s] : %6d\n", id, cnt);
            banner = {banner, output_str};
        end
        
        banner = {banner, "  +-----------------------------------------------------------+\n"};

        if (err_count == 0 && fatal_count == 0) begin
            banner = { banner,
                "\n",
                "   =========================================================\n",
                "   ===                                                   ===\n",
                "   ===                S U C C E S S ! ! !                ===\n",
                "   ===                                                   ===\n",
                "   =========================================================\n"
            };
        end else begin
            banner = { banner,
                "\n",
                "   =========================================================\n",
                "   ===                                                   ===\n",
                "   ===                 F A I L E D ! ! !                 ===\n",
                "   ===                                                   ===\n",
                "   =========================================================\n"
            };
        end
        
        `uvm_info("FINAL_RESULT", banner, UVM_NONE)
    endfunction
endclass

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
        uvm_config_db #(rx_generation_parameters)::set(this, "*", "parameters", this.parameters);

        // Set the agents configuration
        uvm_config_db #(int)::set(this, "environment.input_data_agent.driver",    "valid_probability", parameters.INPUT_DATA_VALID_PROBABILITY);
        uvm_config_db #(int)::set(this, "environment.input_data_agent",           "is_active",         UVM_ACTIVE);
        uvm_config_db #(int)::set(this, "environment.output_data_agent",          "is_active",         UVM_ACTIVE);
        uvm_config_db #(int)::set(this, "environment.control_agent",              "is_active",         UVM_ACTIVE);
        uvm_config_db #(int)::set(this, "environment.parity_agent",               "is_active",         UVM_ACTIVE);
        uvm_config_db #(bit)::set(this, "environment.input_data_agent*",           "is_master",         1'b1);
        uvm_config_db #(bit)::set(this, "environment.output_data_agent*",          "is_master",         1'b0);
        uvm_config_db #(bit)::set(this, "environment.control_agent*",              "is_master",         1'b0);
        uvm_config_db #(bit)::set(this, "environment.parity_agent*",               "is_master",         1'b0);

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

    /*-------------------------------------------------------------------------------
    -- Print Coverage
    -- Call this function at any point to print a coverage snapshot to the CLI.
    -- Usage from a sequence:
    --   begin
    --      rx_base_test test_h;
    --      $cast(test_h, uvm_root::get().find("uvm_test_top"));
    --      test_h.print_coverage();
    --   end
    -------------------------------------------------------------------------------*/
    virtual function void print_coverage();
        this.environment.coverage_subscriber.print_coverage();
    endfunction
endclass

`endif // __RX_BASE_TEST
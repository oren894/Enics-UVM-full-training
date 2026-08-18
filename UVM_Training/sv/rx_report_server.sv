////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_report_server.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Custom UVM report server to intercept, format, and summarize simulation logs, severity counts, and end-of-test status banners.
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_REPORT_SERVER
`define __RX_REPORT_SERVER

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
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

`endif // __RX_REPORT_SERVER

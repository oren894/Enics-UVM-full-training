////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_top_tb.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Top tb for the module rx.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments: 
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_TOP_TB
`define __RX_TOP_TB 
module rx_top_tb ();
    import uvm_pkg::*;

    `include "uvm_macros.svh"

    /*------------------------------------------------------------------------------
    -- Local Signals.
    ------------------------------------------------------------------------------*/
    bit clk;
    bit rst_n;

    /*------------------------------------------------------------------------------
    -- Interfaces.
    ------------------------------------------------------------------------------*/
    // TODO: write an interface for dv.
    dv_if #(.DATA_WIDTH(rx_verification_pack::INPUT_DATA_WIDTH))                input_data           (.clk(clk));
    dv_if #(.DATA_WIDTH(rx_verification_pack::OUTPUT_DATA_WIDTH))               output_data          (.clk(clk));
    dv_if #(.DATA_WIDTH(rx_verification_pack::CONTROL_DATA_WIDTH))              control              (.clk(clk));

    /*-------------------------------------------------------------------------------
    -- Module declarations
    -------------------------------------------------------------------------------*/

    logic [rx_verification_pack::LOCK_VALID_THRESHOLD_DATA_WIDTH-1:0] lock_valid_threshold_val;

    dma_rx_top #(
        .CRC_POLY(16'h1021),
        .CRC_INIT(16'hFFFF)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .lock_valid_threshold(lock_valid_threshold_val), 
        .input_data(input_data.data), 
        .input_valid(input_data.valid), 

        .data_out(output_data.data), 
        .control_out(control.data), 
    
        .control_valid(control.valid),
        .output_valid(output_data.valid),
        .parity_not_valid(), 
        .parity_valid()
    );

    /*------------------------------------------------------------------------------
    -- Lock Valid Threshold Randomization.
    ------------------------------------------------------------------------------*/


    initial begin
        // Randomize the value
        void'(std::randomize(lock_valid_threshold_val) with { 
            lock_valid_threshold_val inside {[rx_verification_pack::MIN_LOCK_VALID_THRESHOLD : rx_verification_pack::MAX_LOCK_VALID_THRESHOLD]};
            lock_valid_threshold_val dist {
                rx_verification_pack::OPTIMAL_LOCK_VALID_THRESHOLD                      :/ 25, 
                [rx_verification_pack::MIN_LOCK_VALID_THRESHOLD : rx_verification_pack::MAX_LOCK_VALID_THRESHOLD] :/ 75
            };
        });
        
        // Share with environment components
        uvm_config_db #(int unsigned)::set(null, "*", "lock_valid_threshold_val", lock_valid_threshold_val);
    end

    /*------------------------------------------------------------------------------
    -- Clock.
    ------------------------------------------------------------------------------*/
    always begin
        #rx_verification_pack::CLK_TOGGLE_TIME clk = ~clk;
    end

    /*------------------------------------------------------------------------------
    -- Reset.
    ------------------------------------------------------------------------------*/
    initial begin
        rst_n = 1'b0;
        @(posedge clk);
        rst_n = 1'b1;
    end 

    /*------------------------------------------------------------------------------
    -- Set up environment.
    ------------------------------------------------------------------------------*/
    initial begin

        // Set interfaces.
        uvm_config_db #(virtual dv_if  #(rx_verification_pack::INPUT_DATA_WIDTH))                ::set(null, "uvm_test_top.environment.input_data_agent.*",           "vif", input_data);
        // lock_valid_threshold interface is now driven locally, no need to pass VIF to agent
        uvm_config_db #(virtual dv_if  #(rx_verification_pack::OUTPUT_DATA_WIDTH))               ::set(null, "uvm_test_top.environment.output_data_agent.*",          "vif", output_data); 
        uvm_config_db #(virtual dv_if  #(rx_verification_pack::CONTROL_DATA_WIDTH))              ::set(null, "uvm_test_top.environment.control_agent.*",              "vif", control); 
    end

    /*------------------------------------------------------------------------------
    -- Run Test.
    ------------------------------------------------------------------------------*/
    initial begin

        // Start the test.
        uvm_root::get().run_test("rx_base_test");
    end
    // FSM states
    typedef enum logic [2:0]{
        FSM_NOT_LOCKED,
        FSM_MAYBE_LOCKED,
        FSM_LOCKED,
        FSM_FATAL
    } fsm_state_t;
    
    initial begin
        wait(dut.fsm_current_state == FSM_LOCKED);
        $display("FSM is locked at time %0t", $time);
        #100;
        $finish();
    end
endmodule

`endif // __RX_TOP_TB
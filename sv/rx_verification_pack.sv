////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_verification_pack.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Package containing common constants, parameters, and UVM environment settings used across the RX verification suite.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_VERIFICATION_PACK
`define __RX_VERIFICATION_PACK

package rx_verification_pack; 

    /*------------------------------------------------------------------------------
    -- Simulation Parameters.
    ------------------------------------------------------------------------------*/
    time CLK_TOGGLE_TIME = 5ns;
    bit  TOPOLOGY        = 1'b0;

    /*------------------------------------------------------------------------------
    -- Interfaces parameters.
    ------------------------------------------------------------------------------*/
    localparam int unsigned INPUT_DATA_WIDTH                = 4;
    localparam int unsigned INPUT_SEQUENCE_ITEM_WIDTH       = 8;
    localparam int unsigned LOCK_VALID_THRESHOLD_DATA_WIDTH = 16;
    localparam int unsigned OUTPUT_DATA_WIDTH               = 32;
    localparam int unsigned CONTROL_DATA_WIDTH              = 16;
    localparam int unsigned PARITY_INDICATOR_WIDTH          = 1;

    /*------------------------------------------------------------------------------
    -- Input Data Parameters.
    ------------------------------------------------------------------------------*/
    localparam int unsigned LENGTH_DATA_WIDTH      = 16;
    localparam int unsigned LENGTH_CRC_DATA_WIDTH  = 16;
    localparam int unsigned CONTROL_CRC_DATA_WIDTH = 16;
    localparam int unsigned PARITY_DATA_WIDTH      = 32;

    /*------------------------------------------------------------------------------
    -- Architecture Data Parameters.
    ------------------------------------------------------------------------------*/
    localparam int unsigned MIN_DATA_SIZE               = 4;
    localparam int unsigned MAX_DATA_SIZE               = 8192;
    localparam int unsigned OPTIMAL_DATA_SIZE           = 4096;
    localparam int unsigned MIN_LOCK_VALID_THRESHOLD    = 2;
    localparam int unsigned MAX_LOCK_VALID_THRESHOLD    = 12;
    localparam int unsigned OPTIMAL_LOCK_VALID_THRESHOLD = 7;

    localparam int unsigned SLIDING_WINDOW_WIDTH = LENGTH_DATA_WIDTH + LENGTH_CRC_DATA_WIDTH;
    localparam int unsigned FRAME_WIDTH          = SLIDING_WINDOW_WIDTH + $bits(byte); // one extra byte for full offset coverage
    localparam int unsigned FRAME_WIDTH_IN_BYTES = FRAME_WIDTH / $bits(byte);

    // Pre-computed byte widths for each packet field (avoids repeated /$bits(byte) throughout the codebase)
    localparam int unsigned LENGTH_DATA_WIDTH_IN_BYTES   = LENGTH_DATA_WIDTH      / $bits(byte);
    localparam int unsigned LENGTH_CRC_WIDTH_IN_BYTES    = LENGTH_CRC_DATA_WIDTH  / $bits(byte);
    localparam int unsigned LENGTH_AND_CRC_BYTES         = LENGTH_DATA_WIDTH_IN_BYTES + LENGTH_CRC_WIDTH_IN_BYTES;

    localparam int unsigned CONTROL_DATA_WIDTH_IN_BYTES  = CONTROL_DATA_WIDTH     / $bits(byte);
    localparam int unsigned CONTROL_CRC_WIDTH_IN_BYTES   = CONTROL_CRC_DATA_WIDTH / $bits(byte);
    localparam int unsigned CONTROL_AND_CRC_BYTES        = CONTROL_DATA_WIDTH_IN_BYTES + CONTROL_CRC_WIDTH_IN_BYTES;

    localparam int unsigned PARITY_BYTES                 = PARITY_DATA_WIDTH      / $bits(byte);

    /*------------------------------------------------------------------------------
    -- CRC Parameters.
    ------------------------------------------------------------------------------*/
    localparam bit [15:0] CRC_LEN_POLY = 16'h1021;
    localparam bit [15:0] CRC_LEN_INIT = 16'hFFFF;
    
    localparam bit [15:0] CRC_CTRL_POLY = 16'h8005;
    localparam bit [15:0] CRC_CTRL_INIT = 16'h0000;
endpackage

`endif // __RX_VERIFICATION_PACK
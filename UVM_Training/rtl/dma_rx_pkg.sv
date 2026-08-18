`timescale 1ns/1ps

package dma_rx_pkg;

    // Import shared packages
    import dma_crc_pkg::*;
    import dma_config_pkg::*;

    // Length and parity field sizes
    parameter LEN_CRC_LENGTH = 8;      // Length of the length and CRC fields in bits (8 NIBBLES = 32 BITS)
    parameter CTRL_CRC_LENGTH = 8;     // 8 nibbles = 32 bits (NEW)
    parameter PARITY_CHECK_LENGTH = 8; // Length of the parity check in bits (8 NIBBLES = 32 BITS)

    // FSM states
    typedef enum logic [2:0]{
        FSM_NOT_LOCKED,
        FSM_MAYBE_LOCKED,
        FSM_LOCKED,
        FSM_FATAL
    } fsm_state_t;

    // Phase states
    typedef enum logic [2:0] {
        PHASE_NONE = 3'd0,
        PHASE_LEN  = 3'd1,
        PHASE_CTRL = 3'd2,
        PHASE_DATA = 3'd3,
        PHASE_PARITY = 3'd4
    } phase_state_t;

endpackage

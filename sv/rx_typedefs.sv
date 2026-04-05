////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_typedef.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Typedef file for the rx.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_TYPEDEF
`define __RX_TYPEDEF

// Removed implicit import





// Agents.
typedef dv_agent #(.DATA_WIDTH(rx_verification_pack::INPUT_DATA_WIDTH), .SEQUENCE_ITEM_WIDTH(rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH)) rx_input_data_agent;

typedef dv_agent #(.DATA_WIDTH(rx_verification_pack::OUTPUT_DATA_WIDTH))               rx_output_data_agent;
typedef dv_agent #(.DATA_WIDTH(rx_verification_pack::CONTROL_DATA_WIDTH))              rx_control_agent;
typedef dv_agent #(.DATA_WIDTH(rx_verification_pack::PARITY_INDICATOR_WIDTH))          rx_parity_agent;

// Scoreboards
typedef rx_scoreboard #(.DATA_WIDTH(rx_verification_pack::OUTPUT_DATA_WIDTH))  rx_output_data_scoreboard;
typedef rx_scoreboard #(.DATA_WIDTH(rx_verification_pack::CONTROL_DATA_WIDTH)) rx_control_scoreboard;
typedef rx_scoreboard #(.DATA_WIDTH(rx_verification_pack::PARITY_INDICATOR_WIDTH)) rx_parity_scoreboard;

/*-------------------------------------------------------------------------------
-- Types & Enums.
-------------------------------------------------------------------------------*/
typedef enum int unsigned {
    NOT_LOCKED,
    MAYBE_LOCKED,
    LOCKED
} state_e;

typedef enum int unsigned {
    PACKET_LENGTH,
    PACKET_CONTROL,
    PACKET_DATA,
    PACKET_PARITY
} packet_state_e;

typedef enum int unsigned {
    TEST_REGULAR,
    TEST_REAL
} rx_test_type_e;

typedef enum int unsigned {
    LOCK_REGULAR,
    LOCK_ONE_PACKET_OUT,
    LOCK_PHASE_CHANGE,
    LOCK_HARD_NOT_LOCKED,
    LOCK_SOFT_NOT_LOCKED
} rx_lock_type_e;

`endif // __RX_TYPEDEF
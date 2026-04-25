////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_typedefs.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Package containing type definitions, enums, and structured data types used by the RX sequences, items, and RTL.
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
    LOCK_SINGLE_BIT_ERR,
    LOCK_MULTI_BIT_ERR
} rx_lock_type_e;

typedef enum int unsigned {
    SEQ_WAIT_EMPTY,
    SEQ_WAIT_4K
} seq_state_e;
`endif // __RX_TYPEDEF
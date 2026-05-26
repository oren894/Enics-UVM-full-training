////////////////////////////////////////////////////////////////////////////////
//
// File name    : final_rx_generation_parameters.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Configuration object containing test-level generation parameters, limits, and probability weights for randomized sequences.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_GENERATION_PARAMETERS
`define __RX_GENERATION_PARAMETERS

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
class rx_generation_parameters extends uvm_object; 

    /*------------------------------------------------------------------------------
    -- Run type probabilities
    -- These determine the likelihood of selecting the overall test flow.
    -- The values act as weights in a probability distribution.
    --   RUN_RANDOM_TEST_P : Weight to run TEST_REGULAR (faster, fully randomized lengths).
    --   RUN_REAL_TEST_P   : Weight to run TEST_REAL (very long, simulates real-world traffic patterns).
    ------------------------------------------------------------------------------*/
    int unsigned RUN_RANDOM_TEST_P = 50;
    int unsigned RUN_REAL_TEST_P   = 50;

    /*------------------------------------------------------------------------------
    -- Lock type probabilities
    -- These define the relative weights for how the RX logic acquires its initial lock.
    --   LOCK_REGULAR_TEST_P        : Normal lock acquisition with standard packets.
    --   LOCK_ONE_PACKET_OUT_TEST_P : Lock using a single packet of non-minimal length.
    --   LOCK_PHASE_CHANGE_TEST_P   : Inject a phase change (half packet) before locking.
    --   LOCK_SINGLE_BIT_ERR_TEST_P : Inject a single bit error during lock (currently 0/disabled).
    --   LOCK_MULTI_BIT_ERR_TEST_P  : Inject a multi-bit/length error during the lock sequence.
    ------------------------------------------------------------------------------*/
    int unsigned LOCK_REGULAR_TEST_P          = 1;
    int unsigned LOCK_ONE_PACKET_OUT_TEST_P   = 1;
    int unsigned LOCK_PHASE_CHANGE_TEST_P     = 1;
    int unsigned LOCK_SINGLE_BIT_ERR_TEST_P   = 0;// NOT RELEVANT FOR NOW BECAUSE DUT DO NOT SUPPORT THIS.
    int unsigned LOCK_MULTI_BIT_ERR_TEST_P    = 1;
    
    /*------------------------------------------------------------------------------
    -- Valid probabilities for the agent
    -- These determine the distribution of 'valid' cycles on the bus, controlling throughput.
    -- Values represent percentages and should ideally sum to 100.
    --   INPUT_DATA_VALID_100_PERCENT_P  : Data is sent every clock cycle (maximum bandwidth).
    --   INPUT_DATA_VALID_25_PERCENT_P   : Data is sent 25% of the time (low bandwidth).
    --   INPUT_DATA_VALID_1_TO_4_RATIO_P : Data is sent intermittently in bursts (1 valid out of 4).
    ------------------------------------------------------------------------------*/
    rand int unsigned INPUT_DATA_VALID_PROBABILITY; // Randomized stimulus field


    int unsigned INPUT_DATA_VALID_100_PERCENT_P  = 33;
    int unsigned INPUT_DATA_VALID_25_PERCENT_P   = 33;
    int unsigned INPUT_DATA_VALID_1_TO_4_RATIO_P = 34;
    
    /*------------------------------------------------------------------------------
    -- Message limits for TEST_REGULAR
    -- Controls the total number of packets sent in a TEST_REGULAR scenario.
    -- This test type is relatively fast (typically 1-2 minutes).
    ------------------------------------------------------------------------------*/
    int unsigned MIN_MESSAGES_IN_REGULAR_TEST = 100;
    int unsigned MAX_MESSAGES_IN_REGULAR_TEST = 1000;

    /*------------------------------------------------------------------------------
    -- Transaction limits for TEST_REAL
    -- NOTE: In TEST_REAL, EACH transaction repeats sending 0-1000 minimum-length
    -- packets plus 0-100 optimal-length packets. This means a single transaction
    -- can generate over 1,000 packets. 
    -- 
    -- WARNING: Setting MAX_TRANSACTIONS_IN_REAL_TEST to 100 means the test could
    -- generate up to ~110,000 packets, which may take 30-40 minutes of simulation
    -- time to complete! Decrease these values to speed up TEST_REAL execution.
    ------------------------------------------------------------------------------*/
    int unsigned MIN_TRANSACTIONS_IN_REAL_TEST = 10;
    int unsigned MAX_TRANSACTIONS_IN_REAL_TEST = 100;
    
    /*------------------------------------------------------------------------------
    -- Number of packets in TEST_REAL (zero length vs optimal length).
    -- These parameters determine how many packets of each type are sent within
    -- a single "transaction" in TEST_REAL mode.
    ------------------------------------------------------------------------------*/
    int unsigned MIN_ZERO_PACKETS_IN_REAL_TEST = 1;
    int unsigned MAX_ZERO_PACKETS_IN_REAL_TEST = 1000;
    int unsigned MIN_OPTIMAL_PACKETS_IN_REAL_TEST = 1;
    int unsigned MAX_OPTIMAL_PACKETS_IN_REAL_TEST = 100;

    /*------------------------------------------------------------------------------
    -- Packet length limits
    -- Define the minimum, maximum, and optimal payload length (in bytes) used
    -- when constraining packet lengths during sequence generation.
    -- Defaults mirror the rx_verification_pack constants so existing test
    -- behaviour is preserved unless overridden.
    --   MIN_PACKET_LENGTH     : Minimum allowed packet length (bytes). for empty length is 4 bytes
    --   MAX_PACKET_LENGTH     : Maximum allowed packet length (bytes). for max length is 8192 bytes
    --   OPTIMAL_PACKET_LENGTH : Target "optimal" length for TEST_REAL traffic. for optimal length is 4096 bytes
    ------------------------------------------------------------------------------*/
    int unsigned MIN_PACKET_LENGTH     = rx_verification_pack::MIN_DATA_SIZE;
    int unsigned MAX_PACKET_LENGTH     = rx_verification_pack::MAX_DATA_SIZE;
    int unsigned OPTIMAL_PACKET_LENGTH = rx_verification_pack::OPTIMAL_DATA_SIZE;
    
    /*------------------------------------------------------------------------------
    -- Initial Junk Data Size
    -- These define the size range (in bytes) of the initial "junk" data sent at the
    -- very beginning of the test before proper lock acquisition begins.
    -- Sending a random amount of junk creates a random byte phase offset, ensuring 
    -- the DUT can correctly find the start of a packet regardless of alignment.
    -- These values should be kept relatively small so as not to unnecessarily getting wrong into maybe lock state
    -- the start of the actual test scenario.
    --
    --   SEND_PHASE_JUNK : (default=1) Set to 0 to skip the junk/phase-creation
    --                     step entirely at the beginning of the test.
    ------------------------------------------------------------------------------*/
    int unsigned SEND_PHASE_JUNK            = 1;
    int unsigned MIN_LENGTH_FOR_START_JUNK  = 0;
    int unsigned MAX_LENGTH_FOR_START_JUNK  = 100;
    
    /*------------------------------------------------------------------------------
    -- Packet Probabilities for errors
    -- These are percentages (0-100) determining how often certain fields are corrupted
    -- or set to specific edge-case values in standard packet generation.
    --   CONTROL_ZERO_P  : % chance the control field is entirely 0.
    --   LENGTH_ERROR_P  : % chance to inject a length CRC error.
    --   CONTROL_ERROR_P : % chance to inject a control CRC error.
    --   PARITY_ERROR_P  : % chance to inject a parity mismatch error at the end of the packet.
    ------------------------------------------------------------------------------*/
    int unsigned CONTROL_ZERO_P  = 25;
    int unsigned LENGTH_ERROR_P  = 20;
    int unsigned CONTROL_ERROR_P = 20;
    int unsigned PARITY_ERROR_P  = 50;

    /*------------------------------------------------------------------------------
    -- Data Generation Mode
    -- Controls how the data payload bytes are generated for each packet.
    -- Random is the default — no parameter needed to enable it.
    -- Set exactly ONE of the two explicit modes to 1 to override the default;
    -- setting both at once will cause a fatal error in post_randomize.
    --
    --   DATA_MODE_CONST_BYTE : (default=0) Every byte is set to CONST_BYTE_VALUE.
    --   DATA_MODE_COUNTER    : (default=0) Bytes increment as a wrapping counter
    --                          starting from 0.
    --   (neither set)        : Each byte is generated with $urandom (default).
    --
    --   CONST_BYTE_VALUE     : The byte value used when DATA_MODE_CONST_BYTE=1.
    ------------------------------------------------------------------------------*/
    int unsigned DATA_MODE_CONST_BYTE = 0;
    int unsigned DATA_MODE_COUNTER    = 0;
    byte unsigned CONST_BYTE_VALUE    = 8'h00;

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_generation_parameters");
        super.new (name);
    endfunction
endclass

`endif // __RX_GENERATION_PARAMETERS
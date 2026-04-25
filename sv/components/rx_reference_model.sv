////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_reference_model.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: UVM reference model implementing a transaction-level predictor of the RX DUT behavior and FSM lock states.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_REFERENCE_MODEL
`define __RX_REFERENCE_MODEL

import uvm_pkg::*;

`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
class rx_reference_model extends uvm_component;

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_component_utils(rx_reference_model) // Factory registration macro

    /*-------------------------------------------------------------------------------
    -- Ports Declarations.
    -------------------------------------------------------------------------------*/
    `uvm_analysis_imp_decl(_input_data)
    
    // Input
    uvm_analysis_imp_input_data #(dv_monitor_item #(rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH), rx_reference_model) input_data_port = null; // Inbound TLM analysis export for receiving transactions
    
    // Output
    uvm_analysis_port #(dv_monitor_item #(rx_verification_pack::OUTPUT_DATA_WIDTH))  output_data_export = null; // Outbound TLM analysis port for broadcasting transactions
    uvm_analysis_port #(dv_monitor_item #(rx_verification_pack::CONTROL_DATA_WIDTH)) control_export = null; // Outbound TLM analysis port for broadcasting transactions
    uvm_analysis_port #(dv_monitor_item #(1))                                        parity_export = null; // Outbound TLM analysis port for broadcasting transactions
    uvm_analysis_port #(rx_coverage_item)                                            coverage_export = null; // Outbound TLM analysis port for broadcasting transactions

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    // Saves the lock valid threshold value that was configured to the DUT.
    int unsigned lock_valid_threshold_value = 0;
    
    // FSM State
    state_e        current_lock_state   = NOT_LOCKED;
    packet_state_e current_packet_state = PACKET_LENGTH;
    
    // NOT_LOCKED State Variables
    // Frame = (len+crc) bits + 1 extra byte so all 8 bit-offsets can be checked.
    // Only 2 variables needed: window_frame to shift into, bytes_accumulated to know when it's full.


    bit [rx_verification_pack::FRAME_WIDTH-1:0] window_frame       = '0;  // shift register: always slide 1 byte at a time
    int                  bytes_accumulated  = 0;
    int                  locked_phase       = 0;   // Bit-shift offset (0–7)

    // MAYBE_LOCKED & LOCKED State Variables
    int consecutive_valid_packet_counter = 0;
    int expected_msg_length = 0;
    
    // Packet Phase tracking
    int current_packet_state_byte_counter = 0;

    // Coverage sampling variables
    int pkt_num_errors_length = 0;
    int pkt_num_errors_control = 0;
    bit [15:0] pkt_control_val = 0;

    // ---- Byte Counter ----
    // Counts every single byte that write_input_data receives from the monitor.
    longint unsigned total_bytes_received = 0;
    
    // Streaming variables
    bit [31:0] current_word = '0;
    bit [31:0] running_parity_acc = '0; 
    
    // Used to align incoming bits against `locked_phase`
    bit [7:0] prev_raw_byte = '0;


    /*-------------------------------------------------------------------------------
    -- Transaction Sequence Tracking Members
    -------------------------------------------------------------------------------*/
    seq_state_e trans_seq_state = SEQ_WAIT_EMPTY;
    
    int trans_sequence_count = 0;
    bit ten_transactions_done_flag = 0;

    /*-------------------------------------------------------------------------------
    -- CRC Parameters & Functions
    -------------------------------------------------------------------------------*/
    localparam bit [15:0] CRC_LEN_POLY  = 16'h1021;
    localparam bit [15:0] CRC_LEN_INIT  = 16'hFFFF;
    localparam bit [15:0] CRC_CTRL_POLY = 16'h8005;
    localparam bit [15:0] CRC_CTRL_INIT = 16'h0000;

    // Generic CRC16 calculation
    virtual function logic [15:0] calculate_crc16(
        input logic [15:0] data,
        input logic [15:0] polynomial,
        input logic [15:0] init_val
    );
        logic [15:0] crc = init_val;
        for (int i = 15; i >= 0; i--) begin
            if (crc[15] ^ data[i]) crc = (crc << 1) ^ polynomial;
            else                   crc = crc << 1;
        end
        return crc;
    endfunction

    /*-------------------------------------------------------------------------------
    -- Is Len CRC Correct
    -- The function checks if the length CRC is correct.
    ---------------------------------------------------------------------------------
    -- args:
    --   length: The length to check.
    --   received_crc: The received CRC.
    ---------------------------------------------------------------------------------
    -- return: 1 if the CRC is correct, 0 otherwise.
    -------------------------------------------------------------------------------*/
    virtual function bit is_len_crc_correct(input logic [15:0] length, input logic [15:0] received_crc);
        return (calculate_crc16(length, CRC_LEN_POLY, CRC_LEN_INIT) == received_crc);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Is Ctrl CRC Correct
    -- The function checks if the control CRC is correct.
    ---------------------------------------------------------------------------------
    -- args:
    --   data: The data to check.
    --   received_crc: The received CRC.
    ---------------------------------------------------------------------------------
    -- return: 1 if the CRC is correct, 0 otherwise.
    -------------------------------------------------------------------------------*/
    virtual function bit is_ctrl_crc_correct(input logic [15:0] data, input logic [15:0] received_crc);
        return (calculate_crc16(data, CRC_CTRL_POLY, CRC_CTRL_INIT) == received_crc);
    endfunction

    /*-------------------------------------------------------------------------------
    -- FSM Helper Functions
    -------------------------------------------------------------------------------*/



    /*-------------------------------------------------------------------------------
    -- Shift Window
    -- The  function shifts 1 byte into the window (slide left, append at LSB end)
    ---------------------------------------------------------------------------------
    -- args:
    --   incoming_byte: The byte to shift into the window (to the  LSB of the window).
    -------------------------------------------------------------------------------*/
    virtual function void shift_window(byte incoming_byte);
        this.window_frame = (this.window_frame << rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH) | rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH'(incoming_byte);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Is There a Valid Phase
    -- The function goes over all the phases that are saved in the window_frame and 
    -- finds the frame that is correct. A frame is correct when it has a right Crc 
    -- for the length. It can also find out that there is no phase that is correct 
    -- and return that the module is not locked.
    ---------------------------------------------------------------------------------
    -- returns:
    --   phase_found: The phase where the length crc is correct.
    --   1 if a phase is found, 0 otherwise.
    -------------------------------------------------------------------------------*/
    virtual function bit is_there_a_valid_phase(output int phase_found);
        bit [rx_verification_pack::SLIDING_WINDOW_WIDTH-1:0] sliding_window = '0;
        // Check all the phases (every phase is a shift of the window 1 bit right)
        for (int phase = 0; phase < $bits(byte); phase++) begin
            // Save the sliding window of the current phase.
            sliding_window = window_frame[rx_verification_pack::FRAME_WIDTH-1-phase -: rx_verification_pack::SLIDING_WINDOW_WIDTH];
            // Check if the CRC is correct.
            if (is_len_crc_correct(
                .length(sliding_window[rx_verification_pack::SLIDING_WINDOW_WIDTH-1 -: rx_verification_pack::LENGTH_DATA_WIDTH]),
                .received_crc(sliding_window[rx_verification_pack::LENGTH_CRC_DATA_WIDTH-1 : 0])
            )) begin

                // The crc was correct, so we are locked and save the phase.
                phase_found = phase;
                return 1;
            end
        end
        return 0;
    endfunction

    // Error correction for Length/Payload CRC (32-bit: 16-bit data + 16-bit CRC)
    virtual function bit [31:0] check_and_correct_errors_len(bit [31:0] data_with_crc, output int num_errors);
        bit [15:0] data = data_with_crc[31:16];
        bit [15:0] crc  = data_with_crc[15:0];
        bit [15:0] expected_crc = calculate_crc16(data, CRC_LEN_POLY, CRC_LEN_INIT);
        bit [15:0] syndrome = expected_crc ^ crc;
        
        num_errors = 0;
        if (syndrome == 0) begin
            return data_with_crc; // 0 errors
        end
        
        // Single bit error detection/correction via brute force bit-flip
        for (int i = 0; i < 32; i++) begin
            bit [31:0] test_data = data_with_crc;
            test_data[i] = ~test_data[i];
            
            if (calculate_crc16(test_data[31:16], CRC_LEN_POLY, CRC_LEN_INIT) == test_data[15:0]) begin
                num_errors = 1;
                return test_data;
            end
        end
        
        // >1 error
        num_errors = 2; 
        return data_with_crc;
    endfunction

    // Error correction for Control CRC (32-bit: 16-bit data + 16-bit CRC)
    virtual function bit [31:0] check_and_correct_errors_ctrl(bit [31:0] data_with_crc, output int num_errors);
        bit [15:0] data = data_with_crc[31:16];
        bit [15:0] crc  = data_with_crc[15:0];
        bit [15:0] expected_crc = calculate_crc16(data, CRC_CTRL_POLY, CRC_CTRL_INIT);
        bit [15:0] syndrome = expected_crc ^ crc;
        
        num_errors = 0;
        if (syndrome == 0) begin
            return data_with_crc; // 0 errors
        end
        
        // Single bit error detection/correction via brute force bit-flip
        for (int i = 0; i < 32; i++) begin
            bit [31:0] test_data = data_with_crc;
            test_data[i] = ~test_data[i];
            
            if (calculate_crc16(test_data[31:16], CRC_CTRL_POLY, CRC_CTRL_INIT) == test_data[15:0]) begin
                num_errors = 1;
                return test_data;
            end
        end
        
        // >1 error
        num_errors = 2; 
        return data_with_crc;
    endfunction


    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_reference_model", uvm_component parent = null);
        super.new (name, parent);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Build Phase.
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

        // Create port
        this.input_data_port    = new("input_data_port",   this);
        this.output_data_export = new("output_data_export", this);
        this.control_export     = new("control_export", this);
        this.parity_export      = new("parity_export", this);
        this.coverage_export    = new("coverage_export", this);

        // Get lock_valid_threshold_val
        if(!uvm_config_db #(int unsigned)::get(null, "*", "lock_valid_threshold_val", this.lock_valid_threshold_value)) begin
             `uvm_info(this.get_name().toupper(), "Couldn't find lock_valid_threshold_val in config_db, using default 0", UVM_LOW)
        end
    endfunction

    /*-------------------------------------------------------------------------------
    -- Write Input Data (FSM Implementation)
    -------------------------------------------------------------------------------*/
    virtual function void write_input_data(dv_monitor_item #(rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH) item);
        // ---- Local variable declarations (all at top) ----
        byte incoming_byte = item.data;
        bit [rx_verification_pack::SLIDING_WINDOW_WIDTH-1:0] sliding_window = '0;
        byte extracted_byte;
        bit [15:0] two_bytes;

        // ---- Byte Counter ----
        this.total_bytes_received++;
        `uvm_info(this.get_name(), $sformatf("[BYTE_COUNTER] Byte #%0d received: 0x%02h  | lock_state=%s  pkt_state=%s",
            this.total_bytes_received, incoming_byte,
            this.current_lock_state.name(), this.current_packet_state.name()), UVM_HIGH)

        two_bytes = {this.prev_raw_byte, incoming_byte};

        // Correctly shift tracking byte by locked phase unconditionally
        extracted_byte = two_bytes[15 - this.locked_phase -: 8];

        // Unconditionally update the sliding window and previous byte outside the case
        this.current_word = (this.current_word << 8) | extracted_byte;
        this.prev_raw_byte = incoming_byte;
        
        // Shift the new byte into the window
        this.shift_window(incoming_byte);
        
        //  Checking the current lock stage of the model
        case (this.current_lock_state)
            
            // Check if the current byte locks our module
            NOT_LOCKED: begin
                
                // Shift the new byte into the window
                //this.shift_window(incoming_byte);
                
                // Check if we have enough bytes to check for a lock
                if (this.bytes_accumulated < rx_verification_pack::FRAME_WIDTH_IN_BYTES-1) begin
                    this.bytes_accumulated++;
                    return; // Wait until we have all the bytes in order to check for a lock
                end

                // Check if there is a phase were the length crc is correct
                if (is_there_a_valid_phase(this.locked_phase)) begin
                    this.current_lock_state   = MAYBE_LOCKED; // MOVE TO MAYBE_LOCKED
                    this.current_packet_state = PACKET_CONTROL; // MOVE TO PACKET_CONTROL
                    this.current_packet_state_byte_counter   = 0; // RESET THE COUNTER
                    this.consecutive_valid_packet_counter = 1; // We got 1 valid packet
                    // Extract the len+crc word at the locked offset from window_frame
                    sliding_window = this.window_frame[rx_verification_pack::FRAME_WIDTH-1-this.locked_phase -: rx_verification_pack::SLIDING_WINDOW_WIDTH];

                    // Save the length from the window (it is the length of the message).
                    this.expected_msg_length = int'(sliding_window[rx_verification_pack::SLIDING_WINDOW_WIDTH-1 -: rx_verification_pack::LENGTH_DATA_WIDTH]);
                end
            end
            
                // Checks if the length + CRC is correct lock_valid_threshold times.
            MAYBE_LOCKED: begin
                this.current_packet_state_byte_counter++;

                case (this.current_packet_state)
                    PACKET_LENGTH: begin
                        if (this.current_packet_state_byte_counter == rx_verification_pack::LENGTH_AND_CRC_BYTES) begin

                            // -----------------------------------------------------------------------
                            // OPTION A — STRICT (no errors allowed): swap in if you want 0-tolerance
                            // -----------------------------------------------------------------------
                            // bit [LENGTH_DATA_WIDTH-1:0]     len_val = current_word[LENGTH_DATA_WIDTH + LENGTH_CRC_DATA_WIDTH -1 -: LENGTH_DATA_WIDTH];
                            // bit [LENGTH_CRC_DATA_WIDTH-1:0] len_crc = current_word[LENGTH_CRC_DATA_WIDTH-1:0];
                            // if (!is_len_crc_correct(len_val, len_crc)) begin
                            //     current_lock_state = NOT_LOCKED;
                            //     consecutive_valid_packet_counter = 0;
                            //     bytes_accumulated = 0;
                            // end else begin
                            //     expected_msg_length = len_val;
                            //     current_packet_state = PACKET_CONTROL;
                            //     current_packet_state_byte_counter = 0;
                            //     consecutive_valid_packet_counter++;
                            //     if (consecutive_valid_packet_counter >= lock_valid_threshold_value)
                            //         current_lock_state = LOCKED;
                            // end
                            
                            // -----------------------------------------------------------------------
                            // OPTION B (ACTIVE) — same tolerance as LOCKED: 0 or 1-bit error corrected;
                            //                     only 2+ errors → NOT_LOCKED
                            // -----------------------------------------------------------------------
                            int num_errors;
                            bit [31:0] corrected_len = check_and_correct_errors_len(this.current_word, num_errors);

                            if (num_errors > 1) begin // 2+ errors → drop to NOT_LOCKED
                                // Emit dummy transition item here to securely report consecutive packets dropped
                                begin
                                    rx_coverage_item transition_item = new("transition_item");
                                    transition_item.is_state_transition       = 1;
                                    transition_item.consecutive_packets_dropped = this.consecutive_valid_packet_counter;
                                    transition_item.num_errors_length_crc     = num_errors; // always 2 here – needed by length_crc_errors coverpoint
                                    this.coverage_export.write(transition_item);
                                end
                                this.current_lock_state = NOT_LOCKED;
                                this.consecutive_valid_packet_counter = 0;
                                //this.bytes_accumulated = 0;

                                // Immediately check if the current window contains a new valid phase
                                // so we don't have to wait for another incoming byte to try locking again.
                                if (is_there_a_valid_phase(this.locked_phase)) begin
                                    this.current_lock_state   = MAYBE_LOCKED;
                                    this.current_packet_state = PACKET_CONTROL;
                                    this.current_packet_state_byte_counter   = 0;
                                    this.consecutive_valid_packet_counter = 1;
                                    
                                    // Extract the len+crc word at the newly found locked offset
                                    sliding_window = this.window_frame[rx_verification_pack::FRAME_WIDTH-1-this.locked_phase -: rx_verification_pack::SLIDING_WINDOW_WIDTH];
                                    this.expected_msg_length = int'(sliding_window[rx_verification_pack::SLIDING_WINDOW_WIDTH-1 -: rx_verification_pack::LENGTH_DATA_WIDTH]);
                                end
                            end else begin // 0 or 1 error (corrected) → stay in MAYBE_LOCKED / advance
                                this.expected_msg_length = corrected_len[31:16];
                                this.pkt_num_errors_length = num_errors; // Save for coverage
                                this.current_packet_state = PACKET_CONTROL;
                                this.current_packet_state_byte_counter = 0;

                                // Packet Complete
                                this.consecutive_valid_packet_counter++;
                                if (this.consecutive_valid_packet_counter >= this.lock_valid_threshold_value) begin
                                    this.current_lock_state = LOCKED;
                                    
                                    // Emit locked state transition
                                    begin
                                        rx_coverage_item transition_item = new("transition_item");
                                        transition_item.is_state_transition = 1;
                                        transition_item.got_locked = 1;
                                        this.coverage_export.write(transition_item);
                                    end
                                end
                            end
                        end
                    end
                    
                    PACKET_CONTROL: begin
                        if (this.current_packet_state_byte_counter == rx_verification_pack::CONTROL_AND_CRC_BYTES ) begin // Check if we have all the bytes of the control word
                            int num_errors;
                            bit [31:0] corrected_control = check_and_correct_errors_ctrl(this.current_word, num_errors);
                            this.pkt_num_errors_control = num_errors; // Save for coverage
                            this.pkt_control_val = corrected_control[31:16]; // Save for coverage

                            if (this.expected_msg_length == rx_verification_pack::CONTROL_AND_CRC_BYTES) begin
                                this.current_packet_state = PACKET_PARITY; // Move to the next state
                            end else begin
                                this.current_packet_state = PACKET_DATA; // Move to the next state
                            end
                            this.current_packet_state_byte_counter = 0; // Reset the counter
                            // this.data_chunk = '0; // Reset the data chunk
                            this.running_parity_acc = '0; // Reset the running parity accumulator
                        end
                    end
                    
                    PACKET_DATA: begin
                        if (this.current_packet_state_byte_counter % 4 == 0) begin // Check if we have 4 bytes for calculate the running parity
                            this.running_parity_acc ^= this.current_word; // Calculate the running parity
                        end
                        
                        if (this.current_packet_state_byte_counter == this.expected_msg_length - rx_verification_pack::CONTROL_AND_CRC_BYTES) begin // Check if we have all the bytes of the data
                            this.current_packet_state = PACKET_PARITY; // Move to the next state
                            this.current_packet_state_byte_counter = 0; // Reset the counter
                        end
                    end
                    
                    PACKET_PARITY: begin
                        if (this.current_packet_state_byte_counter == rx_verification_pack::PARITY_BYTES ) begin // Check if we have all the bytes of the parity word
                            bit parity_indication;
                            
                            if ((this.running_parity_acc ^ this.current_word) == 32'h0) begin
                                parity_indication = 1'b0; // 0 if Match/Valid
                            end else begin
                                parity_indication = 1'b1; // 1 if Error/Invalid
                            end
                            
                            // begin
                            //     dv_monitor_item #(1) parity_item = new("parity_item");
                            //     parity_item.data = parity_indication;
                            //     this.parity_export.write(parity_item);
                            // end
                            
                            // // Packet Complete
                            // this.consecutive_valid_packet_counter++; // Increment the counter of valid packets
                            // if (this.consecutive_valid_packet_counter >= this.lock_valid_threshold_value) begin // Check if we have lock_valid_threshold_value correct packets
                            //     this.current_lock_state = LOCKED; // Move to LOCKED
                            // end
                            
                            // Next packet immediately starts at Length Phase again
                            this.current_packet_state = PACKET_LENGTH; // Move to the next state
                            this.current_packet_state_byte_counter = 0; // Reset the counter

                            // Emit coverage item for MAYBE_LOCKED
                            begin
                                rx_coverage_item cov_item = new("cov_item");
                                cov_item.length = this.expected_msg_length;
                                cov_item.control = this.pkt_control_val;
                                cov_item.num_errors_length_crc = this.pkt_num_errors_length;
                                cov_item.num_errors_control_crc = this.pkt_num_errors_control;
                                cov_item.parity_error = parity_indication;
                                cov_item.locked_phase = this.locked_phase;
                                this.coverage_export.write(cov_item);
                            end
                        end
                    end
                endcase
            end
            
            LOCKED: begin
                this.current_packet_state_byte_counter++;

                case (this.current_packet_state)
                    PACKET_LENGTH: begin
                        if (this.current_packet_state_byte_counter == 4) begin
                            int num_errors;
                            bit [31:0] corrected_len = check_and_correct_errors_len(this.current_word, num_errors);
                            
                            if (num_errors > 1) begin
                                `uvm_fatal(get_type_name(), "Lock lost due to >1 errors in length+crc")
                                
                                // Drop lock entirely (unreachable after fatal, but kept for completeness)
                                this.current_lock_state = NOT_LOCKED;
                                this.consecutive_valid_packet_counter = 0;
                                //this.bytes_accumulated = 0;
                                //this.window_frame = '0;
                            end else begin
                                // 0 or 1 error (corrected)
                                this.expected_msg_length = corrected_len[31:16];
                                this.pkt_num_errors_length = num_errors; // Save for coverage
                                this.current_packet_state = PACKET_CONTROL;
                                this.current_packet_state_byte_counter = 0;
                            end
                        end
                    end
                    
                    PACKET_CONTROL: begin
                        if (this.current_packet_state_byte_counter == rx_verification_pack::CONTROL_AND_CRC_BYTES) begin
                            int num_errors;
                            bit [31:0] corrected_control = check_and_correct_errors_ctrl(this.current_word, num_errors);
                            
                            if (num_errors > 1) begin
                                // Do NOT send Control Data. But continue flow?
                                // Prompt: "If >2 errors... Do NOT send the control data." (Assuming >1 means 2 or more).
                                this.pkt_num_errors_control = num_errors; // Save for coverage
                                this.pkt_control_val = 0;
                            end else begin
                                bit [15:0] extracted_control_val = corrected_control[31:16];
                                this.pkt_num_errors_control = num_errors; // Save for coverage
                                this.pkt_control_val = extracted_control_val; // Save for coverage
                                if (extracted_control_val != 0) begin
                                    dv_monitor_item #(rx_verification_pack::CONTROL_DATA_WIDTH) ctrl_item = new("ctrl_item");
                                    ctrl_item.data = extracted_control_val;
                                    this.control_export.write(ctrl_item);
                                end
                            end
                            
                            if (this.expected_msg_length == rx_verification_pack::CONTROL_AND_CRC_BYTES) begin
                                this.current_packet_state = PACKET_PARITY;
                            end else begin
                                this.current_packet_state = PACKET_DATA;
                            end
                            this.current_packet_state_byte_counter = 0;
                            // this.data_chunk = '0;
                            this.running_parity_acc = '0;
                        end
                    end
                    
                    PACKET_DATA: begin
                        if (this.current_packet_state_byte_counter % 4 == 0) begin
                            // Every 4 bytes, send a 32-bit chunk out
                            dv_monitor_item #(rx_verification_pack::OUTPUT_DATA_WIDTH) temp_data_item = new("temp_data_item");
                            temp_data_item.data = this.current_word;
                            this.output_data_export.write(temp_data_item);
                            
                            // Running XOR
                            this.running_parity_acc ^= this.current_word;
                        end
                        
                        if (this.current_packet_state_byte_counter == this.expected_msg_length - rx_verification_pack::CONTROL_AND_CRC_BYTES) begin
                            this.current_packet_state = PACKET_PARITY;
                            this.current_packet_state_byte_counter = 0;
                        end
                    end
                    
                    PACKET_PARITY: begin
                        if (this.current_packet_state_byte_counter == 4) begin
                            bit parity_indication;
                            
                            if ((this.running_parity_acc ^ this.current_word) == 32'h0) begin
                                parity_indication = 1'b0; // 0 if Match/Valid
                            end else begin
                                parity_indication = 1'b1; // 1 if Error/Invalid
                            end
                            begin
                                dv_monitor_item #(1) parity_item = new("parity_item");
                                parity_item.data = parity_indication;
                                this.parity_export.write(parity_item);
                            end
                            
                            // Ready for next packet organically
                            this.current_packet_state = PACKET_LENGTH;
                            this.current_packet_state_byte_counter = 0;

                            // ---- Transaction Sequence Logic ----
                            case (this.trans_seq_state)
                                SEQ_WAIT_EMPTY: begin
                                    if (this.expected_msg_length == rx_verification_pack::MIN_DATA_SIZE) begin
                                    end else if (this.expected_msg_length == rx_verification_pack::OPTIMAL_DATA_SIZE) begin
                                        this.trans_seq_state = SEQ_WAIT_4K;
                                    end else begin
                                        this.trans_sequence_count = 0;
                                        this.ten_transactions_done_flag = 0;
                                    end
                                end

                                SEQ_WAIT_4K: begin
                                    if (this.expected_msg_length == rx_verification_pack::OPTIMAL_DATA_SIZE) begin
                                    end else if (this.expected_msg_length > rx_verification_pack::MIN_DATA_SIZE && this.expected_msg_length < rx_verification_pack::OPTIMAL_DATA_SIZE) begin
                                        this.trans_sequence_count++;
                                        this.trans_seq_state = SEQ_WAIT_EMPTY;
                                    end else begin
                                        this.trans_sequence_count = 0;
                                        this.ten_transactions_done_flag = 0;
                                        this.trans_seq_state = SEQ_WAIT_EMPTY;
                                    end
                                end
                            endcase

                            // Sticky: latch to 1 once the threshold is reached, never clear it.
                            if (this.trans_sequence_count >= 10)
                                this.ten_transactions_done_flag = 1;

                            // Emit coverage item for LOCKED
                            // Note: ten_transactions_done_flag is NOT included here.
                            // It is sampled ONCE at end-of-test in extract_phase.
                            begin
                                rx_coverage_item cov_item = new("cov_item");
                                cov_item.length = this.expected_msg_length;
                                cov_item.control = this.pkt_control_val;
                                cov_item.num_errors_length_crc = this.pkt_num_errors_length;
                                cov_item.num_errors_control_crc = this.pkt_num_errors_control;
                                cov_item.parity_error = parity_indication;
                                cov_item.locked_phase = this.locked_phase;
                                this.coverage_export.write(cov_item);
                            end
                        end
                    end
                endcase
            end
        endcase
    endfunction

    /*-------------------------------------------------------------------------------
    -- Extract Phase
    -- Runs ONCE after all test traffic has stopped.
    -- Emits a single dedicated coverage item carrying only the final sticky value
    -- of ten_transactions_done_flag so the covergroup samples it exactly once.
    -------------------------------------------------------------------------------*/
    // =============================================================================
    // Extract Phase
    // -----------------------------------------------------------------------------
    // Executed after the run_phase completes. Used to extract final statistical
    // data, error counts, and scoreboard metrics for final evaluation.
    // =============================================================================
    virtual function void extract_phase(uvm_phase phase);
        super.extract_phase(phase);
        begin
            rx_coverage_item eot_item = new("eot_coverage_item");
            // Only ten_transactions_done_flag is meaningful here; all other fields
            // stay at their default (0) and their coverpoints are unaffected because
            // those bins are never closed by a single zero-valued sample.
            eot_item.ten_transactions_done_flag = this.ten_transactions_done_flag;
            this.coverage_export.write(eot_item);
            `uvm_info(get_name(), $sformatf(
                "[EOT] ten_transactions_done_flag = %0b (trans_sequence_count = %0d)",
                this.ten_transactions_done_flag, this.trans_sequence_count), UVM_LOW)
        end
    endfunction

endclass

`endif // __RX_REFERENCE_MODEL
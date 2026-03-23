////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_reference_model.sv
// Project name : 
// Author       : 
// Date Created : 12/2025
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Item to send to the module rx.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_REFERENCE_MODEL
`define __RX_REFERENCE_MODEL

import uvm_pkg::*;

`include "uvm_macros.svh"

class rx_reference_model extends uvm_component;

    /*-----------------------------------------------------------------------------------
    -- UVM Macros.
    -----------------------------------------------------------------------------------*/
    `uvm_component_utils(rx_reference_model)

    /*-------------------------------------------------------------------------------
    -- Ports Declarations.
    -------------------------------------------------------------------------------*/
    `uvm_analysis_imp_decl(_input_data)
    
    // Input
    uvm_analysis_imp_input_data #(dv_monitor_item #(rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH), rx_reference_model) input_data_port = null; 
    
    // Output
    uvm_analysis_port #(dv_monitor_item #(rx_verification_pack::OUTPUT_DATA_WIDTH))  output_data_export = null;
    uvm_analysis_port #(dv_monitor_item #(rx_verification_pack::CONTROL_DATA_WIDTH)) control_export = null;
    uvm_analysis_port #(dv_monitor_item #(1))                                        parity_export = null;

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
    
    // Streaming variables
    bit [31:0] length_word  = '0;
    bit [31:0] control_word = '0;
    bit [31:0] data_chunk   = '0;
    bit [31:0] parity_word  = '0;
    bit [31:0] running_parity_acc = '0; 
    
    // Used to align incoming bits against `locked_phase`
    bit [7:0] prev_raw_byte = '0;

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
        $display("window_frame = %h", this.window_frame);
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
    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);

        // Create port
        this.input_data_port    = new("input_data_port",   this);
        this.output_data_export = new("output_data_export", this);
        this.control_export     = new("control_export", this);
        this.parity_export      = new("parity_export", this);

        // Get lock_valid_threshold_val
        if(!uvm_config_db #(int unsigned)::get(null, "*", "lock_valid_threshold_val", this.lock_valid_threshold_value)) begin
             `uvm_info(this.get_name().toupper(), "Couldn't find lock_valid_threshold_val in config_db, using default 0", UVM_LOW)
        end
    endfunction

    /*-------------------------------------------------------------------------------
    -- Write Input Data (FSM Implementation)
    -------------------------------------------------------------------------------*/
    virtual function void write_input_data(dv_monitor_item #(rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH) item);
        byte incoming_byte = item.data;
        bit [rx_verification_pack::SLIDING_WINDOW_WIDTH-1:0] sliding_window = '0;
        $display(" Current state = %s", this.current_lock_state.name());
        //  Checking the current lock stage of the model
        case (this.current_lock_state)
            
            // Check if the current byte locks our module
            NOT_LOCKED: begin
                
                // Shift the new byte into the window
                this.shift_window(incoming_byte);
                
                // Check if we have enough bytes to check for a lock
                if (this.bytes_accumulated < rx_verification_pack::FRAME_WIDTH_IN_BYTES) begin
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
                    
                    // Save the byte that just got in order to use this data in the next cycle.
                    this.prev_raw_byte = incoming_byte; 
                end
            end
            
                // Checks if the length + CRC is correct lock_valid_threshold times.
            MAYBE_LOCKED: begin
                byte extracted_byte;
                
                // Save to the extracted byte the next byte of the message (because some of the bits were checked before)
                bit [2 * $bits(byte)-1:0] two_bytes = {this.prev_raw_byte, incoming_byte};
                extracted_byte = two_bytes[$bits(two_bytes)-1 - this.locked_phase -: $bits(byte)]; // TODO: CHECK THIS!!!!
                
                // Save the current byte to the previous byte for the next cycle.
                this.prev_raw_byte = incoming_byte;
                this.current_packet_state_byte_counter++;

                case (this.current_packet_state)
                    PACKET_LENGTH: begin
                        this.length_word = (this.length_word << $bits(byte)) | extracted_byte; // Build the length + crc word
                        if (this.current_packet_state_byte_counter == rx_verification_pack::LENGTH_AND_CRC_BYTES) begin // Check if we have all the bytes in order to check for a lock
                            bit [rx_verification_pack::LENGTH_DATA_WIDTH-1:0] len_val = this.length_word[rx_verification_pack::LENGTH_DATA_WIDTH + rx_verification_pack::LENGTH_CRC_DATA_WIDTH -1 -: rx_verification_pack::LENGTH_DATA_WIDTH];
                            bit [rx_verification_pack::LENGTH_CRC_DATA_WIDTH-1:0] len_crc = this.length_word[rx_verification_pack::LENGTH_CRC_DATA_WIDTH-1:0];
                            
                            // Must be PERFECT in MAYBE_LOCKED. If 1 error, fail.
                            if (!is_len_crc_correct(len_val, len_crc)) begin // If the CRC is not correct, we move to NOT_LOCKED
                                this.current_lock_state = NOT_LOCKED; // Move to NOT_LOCKED
                                this.consecutive_valid_packet_counter = 0; // Reset the counter
                                this.bytes_accumulated = 0; // Reset the counter
                                this.window_frame = '0; // Reset the window frame
                            end else begin // If the CRC is correct we stay in maybe_locked and move to the next state until we got lock_valid_threshold_value correct
                                this.expected_msg_length = len_val - 4; // Save the length of the message
                                this.current_packet_state = PACKET_CONTROL; // Move to the next state
                                this.current_packet_state_byte_counter = 0; // Reset the counter
                                this.control_word = '0; // Reset the control word

                                // Packet Complete
                                
                                this.consecutive_valid_packet_counter++; // Increment the counter of valid packets
                                $display("this.consecutive_valid_packet_counter = %0d, this.lock_valid_threshold_value = %0d", this.consecutive_valid_packet_counter, this.lock_valid_threshold_value);
                                if (this.consecutive_valid_packet_counter >= this.lock_valid_threshold_value) begin // Check if we have lock_valid_threshold_value correct packets
                                    this.current_lock_state = LOCKED; // Move to LOCKED
                                end
                            end
                        end
                    end
                    
                    PACKET_CONTROL: begin
                        this.control_word = (this.control_word << 8) | extracted_byte; // Build the control word
                        if (this.current_packet_state_byte_counter == rx_verification_pack::CONTROL_AND_CRC_BYTES) begin // Check if we have all the bytes of the control word
                            this.current_packet_state = PACKET_DATA; // Move to the next state
                            this.current_packet_state_byte_counter = 0; // Reset the counter
                            this.data_chunk = '0; // Reset the data chunk
                            this.running_parity_acc = '0; // Reset the running parity accumulator
                        end
                    end
                    
                    PACKET_DATA: begin
                        // Assemble 32-bit chunk for running XOR
                        this.data_chunk = (this.data_chunk << 8) | extracted_byte; // Build the data chunk
                        
                        if (this.current_packet_state_byte_counter % 4 == 0) begin // Check if we have 4 bytes for calculate the running parity
                            this.running_parity_acc ^= this.data_chunk; // Calculate the running parity
                            this.data_chunk = '0; // Reset the data chunk
                        end
                        
                        if (this.current_packet_state_byte_counter == this.expected_msg_length - rx_verification_pack::CONTROL_AND_CRC_BYTES) begin // Check if we have all the bytes of the data
                            this.current_packet_state = PACKET_PARITY; // Move to the next state
                            this.current_packet_state_byte_counter = 0; // Reset the counter
                            this.parity_word = '0; // Reset the parity word
                        end
                    end
                    
                    PACKET_PARITY: begin
                        this.parity_word = (this.parity_word << 8) | extracted_byte; // Build the parity word
                        if (this.current_packet_state_byte_counter == rx_verification_pack::PARITY_BYTES) begin // Check if we have all the bytes of the parity word
                            // // Packet Complete
                            // this.consecutive_valid_packet_counter++; // Increment the counter of valid packets
                            // if (this.consecutive_valid_packet_counter >= this.lock_valid_threshold_value) begin // Check if we have lock_valid_threshold_value correct packets
                            //     this.current_lock_state = LOCKED; // Move to LOCKED
                            // end
                            
                            // Next packet immediately starts at Length Phase again
                            this.current_packet_state = PACKET_LENGTH; // Move to the next state
                            this.current_packet_state_byte_counter = 0; // Reset the counter
                            this.length_word = '0; // Reset the length word
                        end
                    end
                endcase
            end
            
            LOCKED: begin
                byte extracted_byte;
                
                $display("**************locked_phase = %s**************", this.locked_phase);
                // Align the bit-shifted byte
                {this.prev_raw_byte, extracted_byte} = {this.prev_raw_byte, incoming_byte} << this.locked_phase;
                if (this.locked_phase == 0) begin
                    extracted_byte = incoming_byte;
                end else begin
                    bit [15:0] two_bytes = {this.prev_raw_byte, incoming_byte};
                    extracted_byte = two_bytes[15 - this.locked_phase -: 8]; // TODO: CHECK THIS!!!!
                end
                
                this.prev_raw_byte = incoming_byte;
                this.current_packet_state_byte_counter++;

                case (this.current_packet_state)
                    PACKET_LENGTH: begin
                        this.length_word = (this.length_word << 8) | extracted_byte;
                        if (this.current_packet_state_byte_counter == 4) begin
                            int num_errors;
                            bit [31:0] corrected_len = check_and_correct_errors_len(this.length_word, num_errors);
                            
                            if (num_errors > 1) begin
                                // Drop lock entirely
                                this.current_lock_state = NOT_LOCKED;
                                this.consecutive_valid_packet_counter = 0;
                                this.bytes_accumulated = 0;
                                this.window_frame = '0;
                            end else begin
                                // 0 or 1 error (corrected)
                                this.expected_msg_length = corrected_len[31:16] - 4;
                                this.current_packet_state = PACKET_CONTROL;
                                this.current_packet_state_byte_counter = 0;
                                this.control_word = '0;
                            end
                        end
                    end
                    
                    PACKET_CONTROL: begin
                        this.control_word = (this.control_word << 8) | extracted_byte;
                        if (this.current_packet_state_byte_counter == 4) begin
                            int num_errors;
                            bit [31:0] corrected_control = check_and_correct_errors_ctrl(this.control_word, num_errors);
                            
                            if (num_errors > 1) begin
                                // Do NOT send Control Data. But continue flow?
                                // Prompt: "If >2 errors... Do NOT send the control data." (Assuming >1 means 2 or more).
                            end else begin
                                bit [15:0] extracted_control_val = corrected_control[31:16];
                                if (extracted_control_val != 0) begin
                                    dv_monitor_item #(rx_verification_pack::CONTROL_DATA_WIDTH) ctrl_item = new("ctrl_item");
                                    ctrl_item.data = extracted_control_val;
                                    this.control_export.write(ctrl_item);
                                end
                            end
                            
                            this.current_packet_state = PACKET_DATA;
                            this.current_packet_state_byte_counter = 0;
                            this.data_chunk = '0;
                            this.running_parity_acc = '0;
                        end
                    end
                    
                    PACKET_DATA: begin
                        // Collect into 32-bit chunk
                        this.data_chunk = (this.data_chunk << 8) | extracted_byte;
                        
                        if (this.current_packet_state_byte_counter % 4 == 0) begin
                            // Every 4 bytes, send a 32-bit chunk out
                            dv_monitor_item #(rx_verification_pack::OUTPUT_DATA_WIDTH) temp_data_item = new("temp_data_item");
                            temp_data_item.data = this.data_chunk;
                            this.output_data_export.write(temp_data_item);
                            
                            // Running XOR
                            this.running_parity_acc ^= this.data_chunk;
                            this.data_chunk = '0;
                        end
                        
                        if (this.current_packet_state_byte_counter == this.expected_msg_length) begin
                            this.current_packet_state = PACKET_PARITY;
                            this.current_packet_state_byte_counter = 0;
                            this.parity_word = '0;
                        end
                    end
                    
                    PACKET_PARITY: begin
                        this.parity_word = (this.parity_word << 8) | extracted_byte;
                        if (this.current_packet_state_byte_counter == 4) begin
                            bit parity_indication;
                            
                            if ((this.running_parity_acc ^ this.parity_word) == 32'h0) begin
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
                            this.length_word = '0;
                        end
                    end
                endcase
            end
        endcase
    endfunction

endclass

`endif // __RX_REFERENCE_MODEL
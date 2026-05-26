////////////////////////////////////////////////////////////////////////////////
//
// File name    : exercise_rx_reference_model.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 05/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Simplified UVM reference model for the basic exercise test.
//
//   Assumptions for the basic test:
//     - No junk / no phase offset → phase is always 0 (byte-aligned)
//     - LOCK_REGULAR only → straightforward lock acquisition
//     - 32-bit window CRC check only (no error correction)
//     - No phase-change recovery — if CRC fails in MAYBE, go to NOT_LOCKED
//     - MAYBE → NOT transition is supported but should not happen in the basic test
//     - Once LOCKED, a CRC failure is fatal (should never happen without errors)
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
    // Lock valid threshold value from DUT configuration
    int unsigned lock_valid_threshold_value = 0;
    
    // FSM State
    state_e        current_lock_state   = NOT_LOCKED;
    packet_state_e current_packet_state = PACKET_LENGTH;
    
    // NOT_LOCKED State Variables
    // 32-bit sliding window: [length(16) + crc(16)]
    // Since phase is always 0 (no junk), we only need to check 1 alignment.
    bit [rx_verification_pack::SLIDING_WINDOW_WIDTH-1:0] window_frame = '0;
    int bytes_accumulated = 0;

    // MAYBE_LOCKED & LOCKED State Variables
    int consecutive_valid_packet_counter = 0;
    int expected_msg_length = 0;
    
    // Packet phase tracking
    int current_packet_state_byte_counter = 0;

    // 32-bit word accumulator (builds current_word from 4 incoming bytes)
    bit [31:0] current_word = '0;
    bit [31:0] running_parity_acc = '0; 

    /*-------------------------------------------------------------------------------
    -- CRC Parameters & Functions
    -------------------------------------------------------------------------------*/
    localparam bit [15:0] CRC_LEN_POLY  = 16'h1021;
    localparam bit [15:0] CRC_LEN_INIT  = 16'hFFFF;
    localparam bit [15:0] CRC_CTRL_POLY = 16'h8005;
    localparam bit [15:0] CRC_CTRL_INIT = 16'h0000;

    /*-------------------------------------------------------------------------------
    -- Calculate CRC16 Generic
    -- Generic function to calculate a 16-bit CRC over 16 bits of data.
    ---------------------------------------------------------------------------------
    -- args:
    --   data: The 16-bit data to calculate CRC for.
    --   polynomial: The CRC polynomial.
    --   init_val: The initial value for the CRC calculation.
    ---------------------------------------------------------------------------------
    -- return: The calculated 16-bit CRC value.
    -------------------------------------------------------------------------------*/
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
    -- Checks if the length CRC is correct (no error correction).
    ---------------------------------------------------------------------------------
    -- args:
    --   length: The 16-bit length value.
    --   received_crc: The 16-bit received CRC.
    ---------------------------------------------------------------------------------
    -- return: 1 if the CRC is correct, 0 otherwise.
    -------------------------------------------------------------------------------*/
    virtual function bit is_len_crc_correct(input logic [15:0] length, input logic [15:0] received_crc);
        return (calculate_crc16(length, CRC_LEN_POLY, CRC_LEN_INIT) == received_crc);
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

        // Create ports
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
    --
    -- Simplified FSM for the basic test:
    --   NOT_LOCKED:  Accumulate 4 bytes into window_frame, check length CRC.
    --                If CRC correct → MAYBE_LOCKED. Phase is always 0.
    --   MAYBE_LOCKED: Parse packet fields (length, control, data, parity).
    --                 At each new packet length, CRC check only (no correction).
    --                 If CRC fails → NOT_LOCKED.
    --                 After lock_valid_threshold consecutive good packets → LOCKED.
    --   LOCKED:      Same packet parsing. Emit data/control/parity to scoreboards.
    --                CRC failure is fatal (should never happen without injected errors).
    -------------------------------------------------------------------------------*/
    virtual function void write_input_data(dv_monitor_item #(rx_verification_pack::INPUT_SEQUENCE_ITEM_WIDTH) item);
        bit [7:0] incoming_byte = item.data; // Must be unsigned to avoid sign-extension

        // Build the 32-bit current_word from incoming bytes (phase=0, no bit-shifting needed)
        this.current_word = (this.current_word << 8) | incoming_byte;

        // FSM
        case (this.current_lock_state)
            
            // =====================================================================
            // NOT_LOCKED: Shift bytes into the 32-bit window and check CRC
            // =====================================================================
            NOT_LOCKED: begin
                // Shift the byte into the window (32-bit: length[16] + crc[16])
                this.window_frame = (this.window_frame << 8) | incoming_byte;
                this.bytes_accumulated++;

                // Wait until we have 4 bytes in the window
                if (this.bytes_accumulated < rx_verification_pack::LENGTH_AND_CRC_BYTES) begin
                    return;
                end

                // We have 4 bytes — check if length CRC is correct
                begin
                    bit [15:0] len_val = this.window_frame[rx_verification_pack::SLIDING_WINDOW_WIDTH-1 -: rx_verification_pack::LENGTH_DATA_WIDTH];
                    bit [15:0] len_crc = this.window_frame[rx_verification_pack::LENGTH_CRC_DATA_WIDTH-1 : 0];

                    if (is_len_crc_correct(len_val, len_crc)) begin
                        // CRC match → move to MAYBE_LOCKED
                        this.current_lock_state                = MAYBE_LOCKED;
                        this.current_packet_state              = PACKET_CONTROL;
                        this.current_packet_state_byte_counter = 0;
                        this.consecutive_valid_packet_counter   = 1;
                        this.expected_msg_length               = int'(len_val);
                    end else begin
                        // No match — reset and try next 4 bytes
                        this.bytes_accumulated = 0;
                        this.window_frame      = '0;
                    end
                end
            end
            
            // =====================================================================
            // MAYBE_LOCKED: Parse packets, assume CRC is always correct.
            //               Count consecutive valid packets → LOCKED when threshold met.
            // =====================================================================
            MAYBE_LOCKED: begin
                this.current_packet_state_byte_counter++;

                case (this.current_packet_state)
                    PACKET_LENGTH: begin
                        if (this.current_packet_state_byte_counter == rx_verification_pack::LENGTH_AND_CRC_BYTES) begin
                            // No CRC check — assume packets are always valid in basic test
                            this.expected_msg_length               = int'(this.current_word[31:16]);
                            this.current_packet_state              = PACKET_CONTROL;
                            this.current_packet_state_byte_counter = 0;

                            // Count this packet
                            this.consecutive_valid_packet_counter++;
                            if (this.consecutive_valid_packet_counter >= this.lock_valid_threshold_value) begin
                                this.current_lock_state = LOCKED;

                                // Emit got_locked coverage item
                                begin
                                    rx_coverage_item transition_item = new("transition_item");
                                    transition_item.is_state_transition = 1;
                                    transition_item.got_locked = 1;
                                    this.coverage_export.write(transition_item);
                                end
                            end
                        end
                    end

                    
                    PACKET_CONTROL: begin
                        if (this.current_packet_state_byte_counter == rx_verification_pack::CONTROL_AND_CRC_BYTES) begin
                            if (this.expected_msg_length == rx_verification_pack::CONTROL_AND_CRC_BYTES) begin
                                this.current_packet_state = PACKET_PARITY;
                            end else begin
                                this.current_packet_state = PACKET_DATA;
                            end
                            this.current_packet_state_byte_counter = 0;
                            this.running_parity_acc = '0;
                        end
                    end
                    
                    PACKET_DATA: begin
                        if (this.current_packet_state_byte_counter % 4 == 0) begin
                            this.running_parity_acc ^= this.current_word;
                        end
                        
                        if (this.current_packet_state_byte_counter == this.expected_msg_length - rx_verification_pack::CONTROL_AND_CRC_BYTES) begin
                            this.current_packet_state = PACKET_PARITY;
                            this.current_packet_state_byte_counter = 0;
                        end
                    end
                    
                    PACKET_PARITY: begin
                        if (this.current_packet_state_byte_counter == rx_verification_pack::PARITY_BYTES) begin
                            // Done with this packet in MAYBE — move to next packet's length
                            this.current_packet_state = PACKET_LENGTH;
                            this.current_packet_state_byte_counter = 0;

                            // Emit coverage item for MAYBE_LOCKED packet
                            begin
                                rx_coverage_item cov_item = new("cov_item");
                                cov_item.length = this.expected_msg_length;
                                this.coverage_export.write(cov_item);
                            end
                        end
                    end
                endcase
            end
            
            // =====================================================================
            // LOCKED: Parse packets and emit data/control/parity to scoreboards.
            //         No CRC checks — assume all packets are valid in basic test.
            // =====================================================================
            LOCKED: begin
                this.current_packet_state_byte_counter++;

                case (this.current_packet_state)
                    PACKET_LENGTH: begin
                        if (this.current_packet_state_byte_counter == rx_verification_pack::LENGTH_AND_CRC_BYTES) begin
                            // No CRC check — assume always valid
                            this.expected_msg_length               = int'(this.current_word[31:16]);
                            this.current_packet_state              = PACKET_CONTROL;
                            this.current_packet_state_byte_counter = 0;
                        end
                    end
                    
                    PACKET_CONTROL: begin
                        if (this.current_packet_state_byte_counter == rx_verification_pack::CONTROL_AND_CRC_BYTES) begin
                            // No CRC check — extract control and forward if non-zero
                            begin
                                bit [15:0] ctrl_val = this.current_word[31:16];
                                if (ctrl_val != 0) begin
                                    dv_monitor_item #(rx_verification_pack::CONTROL_DATA_WIDTH) ctrl_item = new("ctrl_item");
                                    ctrl_item.data = ctrl_val;
                                    this.control_export.write(ctrl_item);
                                end
                            end
                            
                            if (this.expected_msg_length == rx_verification_pack::CONTROL_AND_CRC_BYTES) begin
                                this.current_packet_state = PACKET_PARITY;
                            end else begin
                                this.current_packet_state = PACKET_DATA;
                            end
                            this.current_packet_state_byte_counter = 0;
                            this.running_parity_acc = '0;
                        end
                    end

                    
                    PACKET_DATA: begin
                        if (this.current_packet_state_byte_counter % 4 == 0) begin
                            // Every 4 bytes, send 32-bit chunk to output scoreboard
                            dv_monitor_item #(rx_verification_pack::OUTPUT_DATA_WIDTH) temp_data_item = new("temp_data_item");
                            temp_data_item.data = this.current_word;
                            this.output_data_export.write(temp_data_item);
                            
                            // Running XOR for parity calculation
                            this.running_parity_acc ^= this.current_word;
                        end
                        
                        if (this.current_packet_state_byte_counter == this.expected_msg_length - rx_verification_pack::CONTROL_AND_CRC_BYTES) begin
                            this.current_packet_state = PACKET_PARITY;
                            this.current_packet_state_byte_counter = 0;
                        end
                    end
                    
                    PACKET_PARITY: begin
                        if (this.current_packet_state_byte_counter == rx_verification_pack::PARITY_BYTES) begin
                            bit parity_indication;
                            
                            if ((this.running_parity_acc ^ this.current_word) == 32'h0) begin
                                parity_indication = 1'b0; // Valid
                            end else begin
                                parity_indication = 1'b1; // Error
                            end

                            // Send parity result to scoreboard
                            begin
                                dv_monitor_item #(1) parity_item = new("parity_item");
                                parity_item.data = parity_indication;
                                this.parity_export.write(parity_item);
                            end
                            
                            // Ready for next packet
                            this.current_packet_state = PACKET_LENGTH;
                            this.current_packet_state_byte_counter = 0;

                            // Emit coverage item for LOCKED packet
                            begin
                                rx_coverage_item cov_item = new("cov_item");
                                cov_item.length = this.expected_msg_length;
                                this.coverage_export.write(cov_item);
                            end
                        end
                    end
                endcase
            end
        endcase
    endfunction

endclass

`endif // __RX_REFERENCE_MODEL

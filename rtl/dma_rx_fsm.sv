`timescale 1ns/1ps

module dma_rx_fsm 
    import dma_rx_pkg::*;
(
    input logic clk,
    input logic rst_n,
    input logic [15:0] lock_valid_threshold,
    
    // Length detection inputs
    input logic len_any_valid,
    input logic len_crc_ok_or_fixed,
    
    // Data counter input
    input logic [16:0] data_nibble_counter,
    input logic phase_data_length_end,
    
    // FSM outputs
    output fsm_state_t fsm_current_state,
    output fsm_state_t fsm_next_state,
    output logic fsm_locked_status,
    output logic fsm_crc_detection_enable,
    output logic fsm_data_processing_enable,
    output logic fsm_parity_check_enable,
    output logic fsm_is_locked
);

    // fsm_state_t fsm_next_state;
    logic [15:0] fsm_lock_attempt_count;
    logic [15:0] fsm_next_lock_attempt_count;

    // FSM state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm_current_state <= FSM_NOT_LOCKED;
        end else begin
            fsm_current_state <= fsm_next_state;
        end
    end

    // Lock attempt counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm_lock_attempt_count <= 3'b0;
        end else begin // no need input_valid check, we update every cycle
            fsm_lock_attempt_count <= fsm_next_lock_attempt_count;
        end
    end

    // FSM next state logic and control signals
    always_comb begin
        // Default values
        fsm_next_state = fsm_current_state;
        fsm_next_lock_attempt_count = fsm_lock_attempt_count;
        fsm_locked_status = 1'b0;
        fsm_crc_detection_enable = 1'b1;
        fsm_data_processing_enable = 1'b0;
        fsm_parity_check_enable = 1'b0;
        fsm_is_locked = (fsm_current_state == FSM_LOCKED || fsm_current_state == FSM_MAYBE_LOCKED);

        case (fsm_current_state)
            FSM_NOT_LOCKED: begin
                fsm_crc_detection_enable = 1'b1;
                if (len_any_valid || len_crc_ok_or_fixed) begin
                    fsm_next_state = FSM_MAYBE_LOCKED;
                    fsm_next_lock_attempt_count = 3'b001;
                end
            end
            
            FSM_MAYBE_LOCKED: begin
                fsm_crc_detection_enable = 1'b1;
                // Only increment counter when we see a valid CRC at the right time
                if (phase_data_length_end && len_crc_ok_or_fixed) begin
                    fsm_next_lock_attempt_count = fsm_lock_attempt_count + 1;
                end
                
                // Check if we have enough valid attempts to lock
                // Use the incremented value for the comparison
                if ((phase_data_length_end && len_crc_ok_or_fixed && 
                     (fsm_lock_attempt_count + 1) >= lock_valid_threshold)) begin
                    fsm_next_state = FSM_LOCKED;
                    fsm_locked_status = 1'b1;
                end
                // Jump back to NOT_LOCKED if CRC fails at nibble boundary
                else if (phase_data_length_end && !len_crc_ok_or_fixed) begin
                    fsm_next_state = FSM_NOT_LOCKED;
                    fsm_next_lock_attempt_count = 3'b0;
                end
            end
            
            FSM_LOCKED: begin
                fsm_locked_status = 1'b1;
                fsm_data_processing_enable = 1'b1;
                fsm_parity_check_enable = 1'b1;
                
                if (phase_data_length_end) begin                    
                    // Jump back to NOT_LOCKED if CRC fails
                    if (!len_crc_ok_or_fixed) begin
                        fsm_next_state = FSM_NOT_LOCKED;
                        fsm_next_lock_attempt_count = 3'b0;
                    end
                end
            end
            
            FSM_FATAL: begin
                fsm_next_state = FSM_FATAL;
            end
            
            default: begin
                fsm_next_state = FSM_NOT_LOCKED;
            end
        endcase
    end

endmodule

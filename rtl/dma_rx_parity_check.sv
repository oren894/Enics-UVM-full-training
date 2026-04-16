`timescale 1ns/1ps

module dma_rx_parity_check 
    import dma_rx_pkg::*;
(
    input logic clk,
    input logic rst_n,
    input logic input_valid,
    input logic [3:0] input_data,
    
    // FSM state inputs
    input logic fsm_parity_check_enable,
    input fsm_state_t fsm_current_state,
    
    // Phase control inputs
    input logic phase_next_data_active,
    input logic phase_data_active,
    input logic phase_next_parity_active,
    
    // Data processing inputs
    input logic [2:0] data_nibble_index,
    input logic [4:0] data_bit_position,
    input logic [31:0] data_buffer_a,
    input logic [31:0] data_buffer_b,
    input logic data_buffer_selector,
    input logic data_next_packet_complete,

    
    // Parity validation outputs
    output logic [31:0] parity_running_xor,
    output logic [31:0] parity_next_running_xor,
    output logic [31:0] parity_received_signature,
    output logic parity_validation_result,
    output logic parity_check_complete,
    output logic parity_not_valid,
    output logic parity_check_was_invalid
);

    // Running parity calculation
    always_comb begin
        parity_next_running_xor = parity_running_xor;
        parity_validation_result = 1'b0;
        parity_check_complete = 1'b0;
        parity_check_was_invalid = 1'b0;
        
        // Update running parity when last nibble of word is received during data phase
        
        // if (phase_next_data_active && data_nibble_index == 7 && input_valid) begin
        if ((fsm_parity_check_enable && phase_next_data_active && data_nibble_index == 7 && input_valid) || (phase_data_active && !phase_next_data_active && input_valid)) begin
            if (data_buffer_selector == 1'b0) begin
                parity_next_running_xor = parity_running_xor ^ (data_buffer_a | (input_data << data_bit_position));
            end else begin
                parity_next_running_xor = parity_running_xor ^ (data_buffer_b | (input_data << data_bit_position));
            end
        end
        
        // Reset parity for next packet
        if (data_next_packet_complete) begin
            parity_next_running_xor = 32'h0;
        end
        
        // Validate parity when packet is complete
        if (data_next_packet_complete && fsm_parity_check_enable) begin
            parity_validation_result = (parity_running_xor == parity_received_signature);
            parity_check_complete = 1'b1;
            // Mark invalid if validation failed
            if (!parity_validation_result) parity_check_was_invalid = 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parity_running_xor <= 32'h0;
        end else begin
            parity_running_xor <= parity_next_running_xor;
        end
    end

    // Received parity signature buffer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parity_received_signature <= 32'b0;
        end
        else if (fsm_current_state == FSM_LOCKED && phase_next_parity_active && input_valid) begin
            parity_received_signature[data_bit_position +: 4] <= input_data;
        end
    end

    // Parity not valid indicator - asserted when parity check fails
    assign parity_not_valid = parity_check_complete && !parity_validation_result;

endmodule

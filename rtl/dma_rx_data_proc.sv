`timescale 1ns/1ps

module dma_rx_data_proc 
    import dma_rx_pkg::*;
(
    input logic clk,
    input logic rst_n,
    input logic input_valid,
    input logic [3:0] input_data,
    
    // Length input
    input logic [15:0] len_extracted_length,
    
    // FSM state inputs
    input logic len_any_valid,
    input logic len_crc_ok_or_fixed,
    input fsm_state_t fsm_current_state,
    input logic fsm_data_processing_enable,
    input fsm_state_t fsm_next_state,
    
    // Phase control inputs  
    input logic phase_next_data_active,
    
    // Data processing outputs
    output logic [15:0] data_packet_length,
    output logic [16:0] data_nibble_counter,
    output logic [16:0] data_next_nibble_counter,
    output logic [31:0] data_buffer_a,
    output logic [31:0] data_buffer_b,
    output logic data_buffer_selector,
    output logic data_next_buffer_selector,
    output logic data_packet_complete,
    output logic data_next_packet_complete,
    output logic [2:0] data_nibble_index,
    output logic [4:0] data_bit_position,
    output logic word_ready_out
);
    logic word_ready;
    logic word_ready_s1;

    // Word completion logic
    assign word_ready = (data_nibble_index == 7) && input_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            word_ready_s1 <= 1'b0;
        end else begin
            word_ready_s1 <= word_ready;
        end
    end

    assign word_ready_out = word_ready_s1;


    // Transfer extracted length to data processing block
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_packet_length <= 16'b0;
        end else begin
            data_packet_length <= len_extracted_length;
        end
    end

    // Register input_valid to avoid timing issues
    logic input_valid_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_valid_reg <= 1'b0;
        end else begin
            input_valid_reg <= input_valid;
        end
    end

    // Nibble counter management
    always_comb begin

        data_next_packet_complete = 1'b0;

        data_next_buffer_selector = data_buffer_selector;

        data_next_nibble_counter = data_nibble_counter;
        if (input_valid_reg) begin
            data_next_nibble_counter = data_nibble_counter + 1;
        end

        data_nibble_index = data_next_nibble_counter[2:0];
        data_bit_position = 28 - (data_nibble_index * 4);
        
        if (fsm_data_processing_enable && (data_next_nibble_counter % 8 == 7)) begin
            data_next_buffer_selector = ~data_buffer_selector;
        end
        // if (data_nibble_counter == LEN_CRC_LENGTH + data_packet_length * 2 + 
        if (fsm_current_state != FSM_NOT_LOCKED && data_nibble_counter == LEN_CRC_LENGTH + data_packet_length * 2 + 
        PARITY_CHECK_LENGTH - 1 && input_valid_reg) begin
            data_next_packet_complete = 1'b1;
            data_next_nibble_counter = 0;
        end
        
        // Special handling during FSM transitions
        if (fsm_current_state == FSM_NOT_LOCKED && (len_any_valid || len_crc_ok_or_fixed)) begin
            data_next_nibble_counter = 8;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_nibble_counter <= 17'b0;
            data_packet_complete <= 1'b0;
        end else begin
            data_nibble_counter <= data_next_nibble_counter;
            data_packet_complete <= data_next_packet_complete;
        end
    end

    // // Data buffer selection and indexing
    // always_comb begin

    // end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_buffer_selector <= 1'b0;
        end else if (input_valid) begin
            data_buffer_selector <= data_next_buffer_selector;
        end
    end

    // Data buffer filling
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_buffer_a <= 32'b0;
            data_buffer_b <= 32'b0;
        end
        else if (fsm_next_state == FSM_LOCKED && 
                 phase_next_data_active &&
                 input_valid) begin 
            if (data_buffer_selector == 1'b0) begin
                data_buffer_a[data_bit_position +: 4] <= input_data;
            end else begin
                data_buffer_b[data_bit_position +: 4] <= input_data;
            end
        end
    end

endmodule

`timescale 1ns/1ps

module dma_rx_top 
    import dma_rx_pkg::*;
    import dma_config_pkg::*;
    import dma_crc_pkg::*;
#(
    parameter CRC_POLY = 16'h1021,
    parameter CRC_INIT = 16'hFFFF
) (
    input logic clk,
    input logic rst_n,
    input logic [15:0] lock_valid_threshold, // threshold for lock attempts
    
    input logic [3:0] input_data, // input data
    input logic input_valid, // valid signal - input data is valid

    // Configuration interface (wire-based from top module)
    input dma_config_t config_in, // configuration structure
    input logic fetch_enable, // signal to fetch new configuration

    output logic [31:0] data_out, // output data
    output logic [15:0] control_out, // control data output
    
    output logic control_valid, // control data valid signal
    output logic output_valid, // valid signal
    output logic parity_not_valid, // parity was invalid at end of packet
    output logic parity_valid, // parity validation result at end of packet
    
    // Memory interface outputs
    output logic [31:0] mem_addr,
    output logic [31:0] mem_data,
    output logic mem_write_enable,
    output logic mem_valid,
    
    // DMA status outputs
    output logic write_complete,
    output logic [15:0] pages_written
);

    // FSM signals
    fsm_state_t fsm_current_state;
    fsm_state_t fsm_next_state;
    logic fsm_locked_status;
    logic fsm_crc_detection_enable;
    logic fsm_data_processing_enable;
    logic fsm_parity_check_enable;
    logic fsm_is_locked;

    // Phase control signals
    logic phase_control_active;
    logic phase_data_active;
    logic phase_data_length_active;
    logic phase_parity_active;
    logic phase_next_control_active;
    logic phase_next_data_active;
    logic phase_next_data_length_active;
    logic phase_next_parity_active;
    logic phase_control_start, phase_control_end;
    logic phase_data_length_start, phase_data_length_end;
    logic phase_data_start, phase_data_end;
    logic phase_parity_start, phase_parity_end;

    // Length detection signals
    logic len_valid_offset_0, len_valid_offset_1, len_valid_offset_2, len_valid_offset_3;
    logic len_any_valid;
    logic [15:0] len_extracted_length;
    logic len_fix_ok;
    logic len_crc_ok_or_fixed;
    logic len_crc_field_one_error;
    logic len_multibit_error;
    crc_analysis_t len_crc_analysis;
    logic [1:0] detected_phase;
    logic [3:0] in_aligned_data;

    // Control processing signals
    logic [31:0] ctrl_header_buffer;
    logic ctrl_fix_ok;
    logic ctrl_crc_ok_or_fixed;
    logic ctrl_crc_field_one_error;
    logic ctrl_multibit_error;
    crc_analysis_t ctrl_crc_analysis;

    // Data processing signals
    logic [15:0] data_packet_length;
    logic [16:0] data_nibble_counter;
    logic [16:0] data_next_nibble_counter;
    logic [31:0] data_buffer_a;
    logic [31:0] data_buffer_b;
    logic data_buffer_selector;
    logic data_next_buffer_selector;
    logic data_packet_complete;
    logic data_next_packet_complete;
    logic [2:0] data_nibble_index;
    logic [4:0] data_bit_position;
    logic word_ready_out;

    // Parity validation signals
    logic [31:0] parity_running_xor;
    logic [31:0] parity_next_running_xor;
    logic [31:0] parity_received_signature;
    logic parity_validation_result;
    logic parity_check_complete;
    // logic parity_not_valid;
    logic parity_check_was_invalid;

    // Output control signals
    logic [31:0] output_data_word;
    logic output_data_valid;
    logic output_parity_valid;

    // Configuration signals
    dma_config_t config_reg_file;
    logic [31:0] busy_transaction;
    
    // Busy transaction indication (32'hFFFF_FFFF = busy, 32'h0000_0000 = ready)
    // Set to busy when write is not complete (active transaction)
    assign busy_transaction = write_complete ? 32'h0000_0000 : 32'hFFFF_FFFF;

    // Current configuration storage
    dma_rx_config u_dma_rx_config (
        .clk(clk),
        .rst_n(rst_n),
        .fetch_enable(fetch_enable),
        .config_in(config_in),
        .busy_in(busy_transaction),
        .config_out(config_reg_file)
    );

    // FSM control block
    dma_rx_fsm u_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .lock_valid_threshold(lock_valid_threshold),
        .len_any_valid(len_any_valid),
        .len_crc_ok_or_fixed(len_crc_ok_or_fixed),
        .data_nibble_counter(data_nibble_counter),
        .fsm_current_state(fsm_current_state),
        .fsm_next_state(fsm_next_state),
        .fsm_locked_status(fsm_locked_status),
        .fsm_crc_detection_enable(fsm_crc_detection_enable),
        .fsm_data_processing_enable(fsm_data_processing_enable),
        .fsm_parity_check_enable(fsm_parity_check_enable),
        .fsm_is_locked(fsm_is_locked),
        .phase_data_length_end(phase_data_length_end)
    );

    // Phase control block
    dma_rx_phase_ctrl u_phase_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .fsm_next_state(fsm_next_state), 
        .data_next_nibble_counter(data_next_nibble_counter),
        .data_packet_length(data_packet_length),
        .phase_control_active(phase_control_active),
        .phase_data_active(phase_data_active),
        .phase_data_length_active(phase_data_length_active),
        .phase_parity_active(phase_parity_active),
        .phase_next_control_active(phase_next_control_active),
        .phase_next_data_active(phase_next_data_active),
        .phase_next_data_length_active(phase_next_data_length_active),
        .phase_next_parity_active(phase_next_parity_active),
        .phase_control_start(phase_control_start),
        .phase_control_end(phase_control_end),
        .phase_data_length_start(phase_data_length_start),
        .phase_data_length_end(phase_data_length_end),
        .phase_data_start(phase_data_start),
        .phase_data_end(phase_data_end),
        .phase_parity_start(phase_parity_start),
        .phase_parity_end(phase_parity_end),
        .fsm_current_state(fsm_current_state)
    );

    // Length detection block
    dma_rx_len_detect u_len_detect (
        .clk(clk),
        .rst_n(rst_n),
        .input_valid(input_valid),
        .input_data(input_data),
        .fsm_is_locked(fsm_is_locked),
        .fsm_current_state(fsm_current_state),
        .phase_data_length_end(phase_data_length_end),
        .data_nibble_counter(data_nibble_counter),
        .len_valid_offset_0(len_valid_offset_0),
        .len_valid_offset_1(len_valid_offset_1),
        .len_valid_offset_2(len_valid_offset_2),
        .len_valid_offset_3(len_valid_offset_3),
        .len_any_valid(len_any_valid),
        .len_extracted_length(len_extracted_length),
        .len_fix_ok(len_fix_ok),
        .len_crc_ok_or_fixed(len_crc_ok_or_fixed),
        .len_crc_field_one_error(len_crc_field_one_error),
        .len_multibit_error(len_multibit_error),
        .len_crc_analysis(len_crc_analysis),
        .detected_phase(detected_phase),
        .in_aligned_data(in_aligned_data)
    );

    // Control processing block
    dma_rx_ctrl_proc u_ctrl_proc (
        .clk(clk),
        .rst_n(rst_n),
        .input_valid(input_valid),
        .input_data(in_aligned_data),
        .fsm_is_locked(fsm_is_locked),
        .phase_control_active(phase_control_active),
        .phase_control_end(phase_control_end),
        .phase_control_start(phase_control_start),
        .phase_next_control_active(phase_next_control_active),
        .data_bit_position(data_bit_position),
        .ctrl_header_buffer(ctrl_header_buffer),
        .ctrl_fix_ok(ctrl_fix_ok),
        .ctrl_crc_ok_or_fixed(ctrl_crc_ok_or_fixed),
        .ctrl_crc_field_one_error(ctrl_crc_field_one_error),
        .ctrl_multibit_error(ctrl_multibit_error),
        .ctrl_crc_analysis(ctrl_crc_analysis)
        // .detected_phase(detected_phase)
    );

    // Data processing block
    dma_rx_data_proc u_data_proc (
        .clk(clk),
        .rst_n(rst_n),
        .input_valid(input_valid),
        .input_data(in_aligned_data),
        .len_extracted_length(len_extracted_length),
        .len_any_valid(len_any_valid),
        .len_crc_ok_or_fixed(len_crc_ok_or_fixed),
        .fsm_current_state(fsm_current_state),
        .fsm_data_processing_enable(fsm_data_processing_enable),
        .fsm_next_state(fsm_next_state), 
        .phase_next_data_active(phase_next_data_active),
        .data_packet_length(data_packet_length),
        .data_nibble_counter(data_nibble_counter),
        .data_next_nibble_counter(data_next_nibble_counter),
        .data_buffer_a(data_buffer_a),
        .data_buffer_b(data_buffer_b),
        .data_buffer_selector(data_buffer_selector),
        .data_next_buffer_selector(data_next_buffer_selector),
        .data_packet_complete(data_packet_complete),
        .data_next_packet_complete(data_next_packet_complete),
        .data_nibble_index(data_nibble_index),
        .data_bit_position(data_bit_position),
        .word_ready_out(word_ready_out)
    );

    // Parity validation block
    dma_rx_parity_check u_parity_check (
        .clk(clk),
        .rst_n(rst_n),
        .input_valid(input_valid),
        .input_data(input_data),
        .fsm_parity_check_enable(fsm_parity_check_enable),
        .fsm_current_state(fsm_current_state),
        .phase_next_data_active(phase_next_data_active),
        .phase_next_parity_active(phase_next_parity_active),
        .data_nibble_index(data_nibble_index),
        .data_bit_position(data_bit_position),
        .data_buffer_a(data_buffer_a),
        .data_buffer_b(data_buffer_b),
        .data_buffer_selector(data_buffer_selector),
        .data_next_packet_complete(data_next_packet_complete),
        .parity_running_xor(parity_running_xor),
        .parity_next_running_xor(parity_next_running_xor),
        .parity_received_signature(parity_received_signature),
        .parity_validation_result(parity_validation_result),
        .parity_check_complete(parity_check_complete),
        .parity_not_valid(parity_not_valid),
        .parity_check_was_invalid(parity_check_was_invalid),
        .phase_data_active(phase_data_active),
        .word_ready_out(word_ready_out)
    );

    // logic [0:15] data_prev_nibble_index;

    // always_ff @(posedge clk or negedge rst_n) begin
    //   if (!rst_n) data_prev_nibble_index <= 16'd0;
    //   else        data_prev_nibble_index <= data_nibble_index;
    // end

    // Output control block
    always_comb begin
        // Default outputs
        output_data_word = (data_buffer_selector == 1'b0) ? data_buffer_b : data_buffer_a;
        output_data_valid = fsm_data_processing_enable && phase_data_active && word_ready_out;
        output_parity_valid = parity_check_complete ? parity_validation_result : 1'b0;
    end

    // Final output assignments
    assign data_out = output_data_word;
    assign output_valid = output_data_valid;
    assign parity_valid = output_parity_valid;
    // assign parity_not_valid = parity_not_valid;

    // Prefer raw when ok or single-bit CRC error; else use corrected when allowed
    assign control_out = 
        (ctrl_crc_analysis.ok_raw || ctrl_crc_field_one_error) ? ctrl_crc_analysis.data_raw :
        (ctrl_fix_ok)                                          ? ctrl_crc_analysis.data_corr :
                                                                ctrl_crc_analysis.data_raw; // fallback

    // Valid when: raw OK  OR  data fixed; also accept 1-bit CRC error detect-only
    // Do not assert control_valid when control is all zeros (null control)
    assign control_valid = (fsm_data_processing_enable) && (ctrl_crc_ok_or_fixed || ctrl_crc_field_one_error) && phase_control_end && (control_out != 16'd0);


    //TODO: fix protocol between config and write module
    // Connect BUSY signal from write module to config module
    // Memory write module - handles DMA transfers to memory using configuration
    dma_rx_write u_dma_write (
        .clk(clk),
        .rst_n(rst_n),
        .config_in(config_reg_file),
        .data_in(output_data_word),
        .data_valid(output_data_valid),
        .control_in(control_out),
        .control_valid(control_valid),
        .mem_addr(mem_addr),
        .mem_data(mem_data),
        .mem_write_enable(mem_write_enable),
        .write_complete(write_complete),
        .pages_written(pages_written)
    );

    // Debug signal
`ifdef DEBUG
    logic do_len_write;
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) do_len_write <= 1'b0;
      else        do_len_write <= input_valid && (len_valid_offset_0 || len_crc_field_one_error);
    end
`endif

endmodule

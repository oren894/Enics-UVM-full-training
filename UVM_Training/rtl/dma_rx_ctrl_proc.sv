`timescale 1ns/1ps

module dma_rx_ctrl_proc 
    import dma_rx_pkg::*,
           dma_crc_pkg::*;
(
    input logic clk,
    input logic rst_n,
    input logic input_valid,
    input logic [3:0] input_data,
    
    // FSM state inputs
    input logic fsm_is_locked,
    
    // Phase control inputs
    input logic phase_control_active,
    input logic phase_control_end,
    input logic phase_control_start,
    input logic phase_next_control_active,
    
    // Data processing inputs
    input logic [4:0] data_bit_position,
    
    // Control processing outputs
    output logic [31:0] ctrl_header_buffer,
    output logic ctrl_fix_ok,
    output logic ctrl_crc_ok_or_fixed,
    output logic ctrl_crc_field_one_error,
    output logic ctrl_multibit_error,
    output crc_analysis_t ctrl_crc_analysis
);

    always_comb begin
        // Only perform control CRC analysis during control phase or at phase end
        if (phase_control_active || phase_control_end) begin
            // Source word (CONTROL uses assembled buffer)
            ctrl_crc_analysis       = crc_check_analyze_word_ctrl(ctrl_header_buffer);
            ctrl_fix_ok             = fsm_is_locked && ctrl_crc_analysis.fix_ok;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             
            ctrl_crc_ok_or_fixed    = ctrl_crc_analysis.ok_raw || ctrl_fix_ok;
            ctrl_crc_field_one_error= phase_control_end && ctrl_crc_analysis.crc_onebit;
            ctrl_multibit_error     = phase_control_end && ctrl_crc_analysis.crc_multibit;
        end else begin
            // Default values when not in control phase
            ctrl_crc_analysis       = '{default: '0};
            ctrl_fix_ok             = 1'b0;
            ctrl_crc_ok_or_fixed    = 1'b0;
            ctrl_crc_field_one_error= 1'b0;
            ctrl_multibit_error     = 1'b0;
        end
    end

    // Control header and control CRC processing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_header_buffer <= 32'b0;
        end else if (input_valid) begin
            // Clear at the start of the control phase
            if (phase_control_start) begin
                ctrl_header_buffer <= 32'b0;
            end
            // Write the nibble for the CURRENT cycle (including the first one)
            if (phase_next_control_active) begin
                ctrl_header_buffer[data_bit_position +: 4] <= input_data;
            end
        end
    end

endmodule

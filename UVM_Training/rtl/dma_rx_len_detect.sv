`timescale 1ns/1ps

module dma_rx_len_detect 
    import dma_rx_pkg::*,
           dma_crc_pkg::*;
(
    input logic clk,
    input logic rst_n,
    input logic input_valid,
    input logic [3:0] input_data,
    
    // FSM state inputs
    input logic fsm_is_locked,
    input fsm_state_t fsm_current_state,
    
    // Phase control inputs
    input logic phase_data_length_end,
    input logic [16:0] data_nibble_counter,
    
    // Length detection outputs
    output logic len_valid_offset_0,
    output logic len_valid_offset_1, 
    output logic len_valid_offset_2, 
    output logic len_valid_offset_3,
    output logic len_any_valid,
    output logic [15:0] len_extracted_length,
    
    // CRC analysis outputs
    output logic len_fix_ok,
    output logic len_crc_ok_or_fixed,
    output logic len_crc_field_one_error,
    output logic len_multibit_error,
    output crc_analysis_t len_crc_analysis,
    output logic [1:0] detected_phase,
    output logic [3:0] in_aligned_data
);

    logic [34:0] len_sliding_window;
    logic [34:0] len_sliding_window_next;
    logic [1:0] detected_phase_comb;
    logic [3:0] aligned_data_internal_s0;
    // logic [3:0] aligned_data_internal_s1;
    // logic [3:0] aligned_data_internal_s2;
    // logic input_valid_reg;

    // Next sliding window logic
    always_comb begin
        len_sliding_window_next = (len_sliding_window << 4) | input_data;
    end
    
    // always_ff @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         aligned_data_internal_s1 <= 4'b0;
    //         aligned_data_internal_s2 <= 4'b0;
    //     end else begin
    //         if (input_valid) begin
    //             aligned_data_internal_s1 <= aligned_data_internal_s0;
    //             aligned_data_internal_s2 <= aligned_data_internal_s1;
    //         end
    //     end
    // end
    always_comb begin
        case(detected_phase)
            2'd0: aligned_data_internal_s0 = len_sliding_window_next[3:0];  // Phase 0: bits [3:0]
            2'd1: aligned_data_internal_s0 = len_sliding_window_next[4:1];  // Phase 1: bits [6:3]
            2'd2: aligned_data_internal_s0 = len_sliding_window_next[5:2];  // Phase 2: bits [5:2]
            2'd3: aligned_data_internal_s0 = len_sliding_window_next[6:3];  // Phase 3: bits [4:1]
            default: aligned_data_internal_s0 = 4'b0;
        endcase
    end

    
    assign in_aligned_data = aligned_data_internal_s0;  // Use s0 directly, not delayed version


    // Sliding window for CRC detection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            len_sliding_window <= 35'b0;
        end else begin
            if (input_valid) begin
                len_sliding_window <= len_sliding_window_next;
            end
        end
    end

    // Register to hold detected_phase when locked
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            detected_phase <= 2'd0;
        end else begin
            if (!fsm_is_locked) begin
                // Only update when not locked
                detected_phase <= detected_phase_comb;
            end
            // When locked, hold the current value
        end
    end

    // CRC validation at different offsets
    always_comb begin
        len_valid_offset_0 = 1'b0;
        len_valid_offset_1 = 1'b0;
        len_valid_offset_2 = 1'b0;
        len_valid_offset_3 = 1'b0;
        
        if (fsm_is_locked && phase_data_length_end) begin
            case(detected_phase)
            2'd0: len_valid_offset_0 = check_crc16_len(len_sliding_window[31:0]);   // bits 0:31
            2'd1: len_valid_offset_1 = check_crc16_len(len_sliding_window[32:1]);   // bits 1:32
            2'd2: len_valid_offset_2 = check_crc16_len(len_sliding_window[33:2]);   // bits 2:33
            2'd3: len_valid_offset_3 = check_crc16_len(len_sliding_window[34:3]);   // bits 3:34
            endcase
        end
        else if (fsm_current_state == FSM_NOT_LOCKED) begin
                len_valid_offset_0 = check_crc16_len_not_locked(len_sliding_window[31:0]);   // bits 0:31
                len_valid_offset_1 = check_crc16_len_not_locked(len_sliding_window[32:1]);   // bits 1:32
                len_valid_offset_2 = check_crc16_len_not_locked(len_sliding_window[33:2]);   // bits 2:33
                len_valid_offset_3 = check_crc16_len_not_locked(len_sliding_window[34:3]);   // bits 3:34
        end
        // Combinational detection logic
        if (len_valid_offset_0) detected_phase_comb = 2'd0;
        else if (len_valid_offset_1) detected_phase_comb = 2'd1;
        else if (len_valid_offset_2) detected_phase_comb = 2'd2;
        else if (len_valid_offset_3) detected_phase_comb = 2'd3;
        else detected_phase_comb = 2'd0; // Default

        len_any_valid = len_valid_offset_0 || len_valid_offset_1 || len_valid_offset_2 || len_valid_offset_3;
    end

    always_comb begin
        // Only perform length CRC analysis during data length phase or at phase end
        if (phase_data_length_end || len_any_valid) begin
            if(len_valid_offset_0) begin
                len_crc_analysis = crc_check_analyze_word_len(len_sliding_window[31:0]);
            end else if (len_valid_offset_1) begin
                len_crc_analysis = crc_check_analyze_word_len(len_sliding_window[32:1]);
            end else if (len_valid_offset_2) begin
                len_crc_analysis = crc_check_analyze_word_len(len_sliding_window[33:2]);
            end else if (len_valid_offset_3) begin
                len_crc_analysis = crc_check_analyze_word_len(len_sliding_window[34:3]);
            end else begin
                // Fallback (should not occur)
                len_crc_analysis = crc_check_analyze_word_len(len_sliding_window[31:0]);
            end
        
            // len_crc_analysis      = crc_check_analyze_word_len(len_sliding_window[31:0]);
            len_fix_ok            = fsm_is_locked && len_crc_analysis.fix_ok;
            len_crc_ok_or_fixed   = len_crc_analysis.ok_raw || len_fix_ok;
            len_crc_field_one_error = phase_data_length_end && len_crc_analysis.crc_onebit;
            len_multibit_error      = phase_data_length_end && len_crc_analysis.crc_multibit;
        end else begin
            // Default values when not in length phase
            len_crc_analysis      = '{default: '0};
            len_fix_ok            = 1'b0;
            len_crc_ok_or_fixed   = 1'b0;
            len_crc_field_one_error = 1'b0;
            len_multibit_error      = 1'b0;
        end
    end

    // Extract length, preferring corrected data on aligned boundary when LOCKED
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            len_extracted_length <= 16'b0;
        end else begin
            if (fsm_is_locked && (data_nibble_counter == 7) && len_fix_ok) begin
                len_extracted_length <= len_crc_analysis.data_corr;      
            end else if (len_valid_offset_0 || len_crc_field_one_error) begin
                len_extracted_length <= len_crc_analysis.data_raw;              // raw aligned OK
            end else if (len_valid_offset_1) begin
                len_extracted_length <= len_sliding_window[32:17];
            end else if (len_valid_offset_2) begin
                len_extracted_length <= len_sliding_window[33:18];
            end else if (len_valid_offset_3) begin
                len_extracted_length <= len_sliding_window[34:19];
            end
        end
    end

endmodule

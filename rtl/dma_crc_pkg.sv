`timescale 1ns/1ps

package dma_crc_pkg;

    // CRC polynomial and initialization parameters
    // Length field CRC - CRC-16-CCITT
    parameter logic [15:0] CRC_LEN_POLY = 16'h1021;
    parameter logic [15:0] CRC_LEN_INIT = 16'hFFFF;
    
    // Control field CRC - CRC-16-IBM/ANSI
    parameter logic [15:0] CRC_CTRL_POLY = 16'h8005;
    parameter logic [15:0] CRC_CTRL_INIT = 16'h0000;

    // CRC16 syndrome lookup table for length field (CRC-16-CCITT)
    parameter logic [15:0] CRC16_LEN_SYNDROME_LUT [0:15] = '{
        16'h1021, // bit 0
        16'h2042, // bit 1
        16'h4084, // bit 2
        16'h8108, // bit 3
        16'h1231, // bit 4
        16'h2462, // bit 5
        16'h48C4, // bit 6
        16'h9188, // bit 7
        16'h3331, // bit 8
        16'h6662, // bit 9
        16'hCCC4, // bit 10
        16'h89A9, // bit 11
        16'h0373, // bit 12
        16'h06E6, // bit 13
        16'h0DCC, // bit 14
        16'h1B98  // bit 15
    };

    // CRC16 syndrome lookup table for control field (CRC-16-IBM/ANSI)
    parameter logic [15:0] CRC16_CTRL_SYNDROME_LUT [0:15] = '{
        16'h8005, // bit 0
        16'h000A, // bit 1
        16'h0014, // bit 2
        16'h0028, // bit 3
        16'h0050, // bit 4
        16'h00A0, // bit 5
        16'h0140, // bit 6
        16'h0280, // bit 7
        16'h0500, // bit 8
        16'h0A00, // bit 9
        16'h1400, // bit 10
        16'h2800, // bit 11
        16'h5000, // bit 12
        16'hA000, // bit 13
        16'h4001, // bit 14
        16'h8002  // bit 15
    };

    // CRC analysis structure
    typedef struct packed {
        logic [15:0] data_raw;      // [31:16]
        logic [15:0] crc_field;     // [15:0]
        logic [15:0] data_corr;     // data_raw ^ mask (if CAM hit)
        logic [15:0] calc_crc;      // CRC(data_raw)
        logic [15:0] syndrome;      // calc_crc ^ crc_field
        logic        cam_hit;       // LUT hit for data-bit correction
        logic        fix_ok;        // CRC(data_corr) == crc_field
        logic        ok_raw;        // calc_crc == crc_field
        logic        ok_or_fixed;   // ok_raw || fix_ok
        logic        crc_onebit;    // CRC field has exactly one bit flipped
        logic        crc_multibit;  // CRC field has >1 bits flipped
    } crc_analysis_t;

    // Generic CRC16 calculation function
    function automatic logic [15:0] calculate_crc16_generic(
        input logic [15:0] data,
        input logic [15:0] polynomial,
        input logic [15:0] init_val
    );
        logic [15:0] crc;
        integer i;

        crc = init_val;

        for (i = 15; i >= 0; i--) begin
            if (crc[15] ^ data[i]) begin
                crc = (crc << 1) ^ polynomial;
            end else begin
                crc = crc << 1;
            end
        end

        return crc;
    endfunction

    // CRC16 calculation function for length field
    function automatic logic [15:0] calculate_crc16_len(input logic [15:0] data);
        return calculate_crc16_generic(data, CRC_LEN_POLY, CRC_LEN_INIT);
    endfunction

    // CRC16 calculation function for control field
    function automatic logic [15:0] calculate_crc16_ctrl(input logic [15:0] data);
        return calculate_crc16_generic(data, CRC_CTRL_POLY, CRC_CTRL_INIT);
    endfunction

    // Legacy function for backward compatibility (uses length CRC)
    function automatic logic [15:0] calculate_crc16(input logic [15:0] data);
        return calculate_crc16_len(data);
    endfunction

    // Generic CRC validation function for 32-bit window: [data][crc]
    function automatic logic check_crc16_generic(
        input logic [31:0] window_data,
        input logic [15:0] polynomial,
        input logic [15:0] init_val
    );
        logic [15:0] data_field;
        logic [15:0] received_crc;
        logic [15:0] calculated_crc;

        data_field   = window_data[31:16];
        received_crc   = window_data[15:0];
        calculated_crc = calculate_crc16_generic(data_field, polynomial, init_val);

        return (calculated_crc == received_crc);
    endfunction

    // CRC validation function for length field
    function automatic logic check_crc16_len(input logic [31:0] window_data);
        return check_crc16_generic(window_data, CRC_LEN_POLY, CRC_LEN_INIT);
    endfunction

    // CRC validation function for control field
    function automatic logic check_crc16_ctrl(input logic [31:0] window_data);
        return check_crc16_generic(window_data, CRC_CTRL_POLY, CRC_CTRL_INIT);
    endfunction

    // Legacy function for backward compatibility (uses length CRC)
    function automatic logic check_crc16(input logic [31:0] window_data);
        return check_crc16_len(window_data);
    endfunction

    // Generic CAM function for syndrome lookup
    function automatic logic [15:0] crc16_cam_data_mask16_generic(
        input  logic [15:0] syndrome,
        input  logic [15:0] syndrome_lut [0:15],
        output logic        hit
    );
        logic [15:0] mask; 
        int k;
        begin
            hit  = 1'b0; 
            mask = 16'h0000;
            for (k = 0; k < 16; k++) begin
                if (syndrome == syndrome_lut[k]) begin
                    hit  = 1'b1;
                    mask = (16'h1 << k); 
                    return mask;
                end
            end
            return mask;
        end
    endfunction

    // CAM function for length field
    function automatic logic [15:0] crc16_cam_data_mask16_len(
        input  logic [15:0] syndrome,
        output logic        hit
    );
        return crc16_cam_data_mask16_generic(syndrome, CRC16_LEN_SYNDROME_LUT, hit);
    endfunction

    // CAM function for control field
    function automatic logic [15:0] crc16_cam_data_mask16_ctrl(
        input  logic [15:0] syndrome,
        output logic        hit
    );
        return crc16_cam_data_mask16_generic(syndrome, CRC16_CTRL_SYNDROME_LUT, hit);
    endfunction

    // Legacy function for backward compatibility (uses length syndrome table)
    function automatic logic [15:0] crc16_cam_data_mask16(
        input  logic [15:0] syndrome,
        output logic        hit
    );
        return crc16_cam_data_mask16_len(syndrome, hit);
    endfunction

    // Generic CRC analysis function
    function automatic crc_analysis_t crc_check_analyze_word_generic(
        input logic [31:0] word,
        input logic [15:0] polynomial,
        input logic [15:0] init_val,
        input logic [15:0] syndrome_lut [0:15]
    );
        crc_analysis_t r;
        logic [15:0] mask;
        logic        hit;

        r.data_raw   = word[31:16];
        r.crc_field  = word[15:0];
        r.calc_crc   = calculate_crc16_generic(r.data_raw, polynomial, init_val);
        r.syndrome   = r.calc_crc ^ r.crc_field;

        mask         = crc16_cam_data_mask16_generic(r.syndrome, syndrome_lut, hit);
        r.cam_hit    = hit;
        r.data_corr  = r.data_raw ^ mask;
        r.fix_ok     = hit && (calculate_crc16_generic(r.data_corr, polynomial, init_val) == r.crc_field);

        r.ok_raw     = (r.calc_crc == r.crc_field);
        r.ok_or_fixed= r.ok_raw || r.fix_ok;

        r.crc_onebit    = 1'b0;
        r.crc_multibit  = 1'b0;
        if (!r.ok_raw && (r.syndrome != 16'h0000)) begin
            if ( (r.syndrome & (r.syndrome - 1)) == 16'h0000 )
                r.crc_onebit = 1'b1;
            else
                r.crc_multibit = 1'b1;
        end
        return r;
    endfunction

    // CRC analysis function for length field
    function automatic crc_analysis_t crc_check_analyze_word_len(input logic [31:0] word);
        return crc_check_analyze_word_generic(word, CRC_LEN_POLY, CRC_LEN_INIT, CRC16_LEN_SYNDROME_LUT);
    endfunction

    // CRC analysis function for control field
    function automatic crc_analysis_t crc_check_analyze_word_ctrl(input logic [31:0] word);
        return crc_check_analyze_word_generic(word, CRC_CTRL_POLY, CRC_CTRL_INIT, CRC16_CTRL_SYNDROME_LUT);
    endfunction

    // Legacy function for backward compatibility (uses length CRC)
    function automatic crc_analysis_t crc_check_analyze_word(input logic [31:0] word);
        return crc_check_analyze_word_len(word);
    endfunction

endpackage

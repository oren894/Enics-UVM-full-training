////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_item.sv
// Project name : rx_uvm_environment
// Author       : Oren Ruthstein
// Date Created : 04/2026
// Company      : Enics
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: UVM sequence item representing an RX packet, containing data payload, headers, parity, and constraints for error injection.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_ITEM
`define __RX_ITEM

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// Class Definition
// -----------------------------------------------------------------------------
// This class extends the standard UVM base library. It inherits core UVM
// functionality including phased execution, factory registration, and logging.
// =============================================================================
class rx_item extends uvm_object;

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/

    rand bit  [rx_verification_pack::LENGTH_DATA_WIDTH      - 1 : 0]                                               length               = '{default : 0}; // Randomized stimulus field
    bit       [rx_verification_pack::LENGTH_CRC_DATA_WIDTH  - 1 : 0]                                               length_crc           = '{default : 0}; 
    rand bit  [rx_verification_pack::CONTROL_DATA_WIDTH     - 1 : 0]                                               control              = '{default : 0}; // Randomized stimulus field
    bit       [rx_verification_pack::CONTROL_CRC_DATA_WIDTH - 1 : 0]                                               control_crc          = '{default : 0}; 
    rand byte                                                                                                      data [$]             = {};             // Randomized stimulus field
    rand bit  [rx_verification_pack::PARITY_DATA_WIDTH      - 1 : 0]                                               parity               = '{default : 0}; // Randomized stimulus field
    rand bit                                                                                                       length_error;                          // Randomized stimulus field
    rand bit                                                                                                       wrong_length;                          // Randomized stimulus field
    rand bit                                                                                                       control_error;                         // Randomized stimulus field
    rand bit                                                                                                       parity_error;                          // Randomized stimulus field
    bit       [rx_verification_pack::LENGTH_DATA_WIDTH  + rx_verification_pack::LENGTH_CRC_DATA_WIDTH  - 1 : 0]    new_length_with_crc;
    bit       [rx_verification_pack::CONTROL_DATA_WIDTH + rx_verification_pack::CONTROL_CRC_DATA_WIDTH - 1 : 0]    new_control_with_crc;
    bit       [rx_verification_pack::PARITY_DATA_WIDTH      - 1 : 0]                                               new_parity;
    rand bit                                                                                                       half_packet;                           // Randomized stimulus field
    /*-------------------------------------------------------------------------------
    -- UVM Macros.
    -------------------------------------------------------------------------------*/
    `uvm_object_utils_begin(rx_item)

        `uvm_field_sarray_int (length,                        UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (length_crc,                    UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (control,                       UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (control_crc,                   UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_queue_int  (data,                          UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (parity,                        UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_int        (length_error,                  UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_int        (wrong_length,                  UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_int        (control_error,                 UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_int        (parity_error,                  UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (new_length_with_crc,           UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (new_control_with_crc,          UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (new_parity,                    UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_int        (half_packet,                   UVM_DEFAULT | UVM_NOPACK)
    `uvm_object_utils_end 

    /*------------------------------------------------------------------------------
    -- Parameters.
    ------------------------------------------------------------------------------*/
    rx_generation_parameters parameters;    /*-------------------------------------------------------------------------------
    -- Constructor
    -- Initializes the rx_item sequence item object.
    ---------------------------------------------------------------------------------
    -- args:
    --   name: String name for the UVM object.
    ---------------------------------------------------------------------------------
    -- return: N/A
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_item");
        super.new(name);
    endfunction

    /*-------------------------------------
    -- CRC Calculation Functions
    -------------------------------------*/

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
    function logic [15:0] calculate_crc16_generic(
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

    /*-------------------------------------------------------------------------------
    -- Calculate CRC16 Len
    -- Specific CRC calculation for the length field using the length polynomial.
    ---------------------------------------------------------------------------------
    -- args:
    --   data: The 16-bit length data to calculate CRC for.
    ---------------------------------------------------------------------------------
    -- return: The calculated 16-bit CRC value.
    -------------------------------------------------------------------------------*/
    function logic [15:0] calculate_crc16_len(input logic [15:0] data);
        return calculate_crc16_generic(data, rx_verification_pack::CRC_LEN_POLY, rx_verification_pack::CRC_LEN_INIT);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Calculate CRC16 Ctrl
    -- Specific CRC calculation for the control field using the control polynomial.
    ---------------------------------------------------------------------------------
    -- args:
    --   data: The 16-bit control data to calculate CRC for.
    ---------------------------------------------------------------------------------
    -- return: The calculated 16-bit CRC value.
    -------------------------------------------------------------------------------*/
    function logic [15:0] calculate_crc16_ctrl(input logic [15:0] data);
        return calculate_crc16_generic(data, rx_verification_pack::CRC_CTRL_POLY, rx_verification_pack::CRC_CTRL_INIT);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Post Randomize
    -- Automatically calculates CRCs, data payloads, and parity after UVM randomization, 
    -- and conditionally injects errors based on generated error flags.
    ---------------------------------------------------------------------------------
    -- args: N/A
    ---------------------------------------------------------------------------------
    -- return: N/A
    -------------------------------------------------------------------------------*/
    function void post_randomize();
        int unsigned bit_index;
        int unsigned num_flips;
        bit [rx_verification_pack::LENGTH_DATA_WIDTH + rx_verification_pack::LENGTH_CRC_DATA_WIDTH - 1 : 0] temp_length;
        bit [rx_verification_pack::CONTROL_DATA_WIDTH + rx_verification_pack::CONTROL_CRC_DATA_WIDTH - 1 : 0] temp_control;
        bit [rx_verification_pack::PARITY_DATA_WIDTH - 1 : 0] temp_parity;
        int unsigned p_width = rx_verification_pack::PARITY_DATA_WIDTH;
        int unsigned data_size;
        int unsigned flipped_indices[$]; // Moved here

        // Calculate CRC for length
        this.length_crc = calculate_crc16_len(this.length);

        // Calculate CRC for control
        this.control_crc = calculate_crc16_ctrl(this.control);

        // Calculate Data
        // Data generation mode is controlled by generation parameters.
        // Random is the implicit default (no flag needed).
        // Set DATA_MODE_CONST_BYTE=1 OR DATA_MODE_COUNTER=1 to override.
        // Setting both at once is an error.
        data_size = this.length - ((rx_verification_pack::CONTROL_DATA_WIDTH + rx_verification_pack::CONTROL_CRC_DATA_WIDTH) / 8);
        this.data.delete();

        begin : data_gen_mode_check
            if (parameters.DATA_MODE_CONST_BYTE && parameters.DATA_MODE_COUNTER) begin
                begin
                    string _fatal_msg;
                    _fatal_msg = $sformatf("Only one data generation mode may be enabled at a time. DATA_MODE_CONST_BYTE=%0d, DATA_MODE_COUNTER=%0d",
                                           parameters.DATA_MODE_CONST_BYTE,
                                           parameters.DATA_MODE_COUNTER);
                    `uvm_fatal("RX_ITEM", _fatal_msg)
                end
            end else if (parameters.DATA_MODE_CONST_BYTE) begin
                // Mode 2: every byte is the configured constant
                for (int i = 0; i < data_size; i++) begin
                    this.data.push_back(parameters.CONST_BYTE_VALUE);
                end
            end else if (parameters.DATA_MODE_COUNTER) begin
                // Mode 3: wrapping counter starting at 0
                for (int i = 0; i < data_size; i++) begin
                    this.data.push_back(byte'(i % 256));
                end
            end else begin
                // Default: fully random bytes
                for (int i = 0; i < data_size; i++) begin
                    this.data.push_back($urandom);
                end
            end
        end
        
        // Calculate Parity
        // RTL places the first received byte into data_buffer_a MSB, 
        // the second into the next byte down, etc., so we match that compilation here.
        this.parity = '0;
        for (int i = 0; i < this.data.size(); i += (p_width / 8)) begin
            bit [rx_verification_pack::PARITY_DATA_WIDTH - 1 : 0] chunk = '0;
            for (int j = 0; j < (p_width / 8); j++) begin
                if (i + j < this.data.size()) begin
                    chunk[(p_width - 1 - 8*j) -: 8] = this.data[i+j];
                end
            end
            this.parity ^= chunk;
        end


        /*/////////////////////////////////////////////
        //                  put errors               //
        /////////////////////////////////////////////*/
        
        
        // Length
        temp_length = {this.length, this.length_crc}; 
        if (this.wrong_length) begin
            // Inject at least 2 errors
            num_flips = $urandom_range(2, $bits(temp_length));
            while (flipped_indices.size() < num_flips) begin
                bit_index = $urandom_range(0, $bits(temp_length) - 1);
                if (!(bit_index inside {flipped_indices})) begin
                    temp_length[bit_index] = ~temp_length[bit_index];
                    flipped_indices.push_back(bit_index);
                end
            end
        end else if (this.length_error) begin
            //Inject 1 error
            bit_index = $urandom_range(0, $bits(temp_length) - 1);
            temp_length[bit_index] = ~temp_length[bit_index];
        end
        this.new_length_with_crc = temp_length;

        // Control
        temp_control = {this.control, this.control_crc};
        if (this.control_error) begin
            bit_index = $urandom_range(0, $bits(temp_control) - 1);
            temp_control[bit_index] = ~temp_control[bit_index];
        end
        this.new_control_with_crc = temp_control;

        // Parity
        temp_parity = this.parity;
        if (this.parity_error) begin
            num_flips = $urandom_range(1, $bits(temp_parity)); 
            if (num_flips % 2 == 0) num_flips++; // Ensure odd number of flips
            for (int i = 0; i < num_flips; i++) begin
                bit_index = $urandom_range(0, $bits(temp_parity) - 1);
                temp_parity[bit_index] = ~temp_parity[bit_index];
            end
        end
        this.new_parity = temp_parity;
    endfunction

    /*-------------------------------------------------------------------------------
    -- Do Pack
    -- Serializes the sequence item fields (length, control, data, parity) into a 
    -- bitstream using the standard UVM packer.
    ---------------------------------------------------------------------------------
    -- args:
    --   packer: The UVM packer object used to construct the bitstream.
    ---------------------------------------------------------------------------------
    -- return: N/A
    -------------------------------------------------------------------------------*/
    virtual function void do_pack(uvm_packer packer);
        // 1. Construct stream of current item fields
        // Normal: Pack Length, Control, Data, Parity.
        packer.pack_field_int(this.new_length_with_crc, $bits(this.new_length_with_crc));
        packer.pack_field_int(this.new_control_with_crc, $bits(this.new_control_with_crc));
        // Pack Data
        foreach(this.data[i]) begin
            packer.pack_field_int(this.data[i], $bits(this.data[i]));
        end
        // Pack Parity
        packer.pack_field_int(this.new_parity, $bits(this.new_parity));
    endfunction

    /*-------------------------------------------------------------------------------
    -- Do Unpack
    -- Deserializes a bitstream into the sequence item fields (length, control, data, 
    -- parity) using the standard UVM packer.
    ---------------------------------------------------------------------------------
    -- args:
    --   packer: The UVM packer object providing the bitstream.
    ---------------------------------------------------------------------------------
    -- return: N/A
    -------------------------------------------------------------------------------*/
    virtual function void do_unpack(uvm_packer packer);
        int unsigned data_length = (packer.get_packed_size() - rx_verification_pack::LENGTH_DATA_WIDTH
                - rx_verification_pack::LENGTH_CRC_DATA_WIDTH - rx_verification_pack::CONTROL_DATA_WIDTH 
                - rx_verification_pack::CONTROL_CRC_DATA_WIDTH - rx_verification_pack::PARITY_DATA_WIDTH) / $bits(byte);

        // Unpack the length
        this.length = packer.unpack_field_int(rx_verification_pack::LENGTH_DATA_WIDTH);

        // Unpack the length crc
        this.length_crc = packer.unpack_field_int(rx_verification_pack::LENGTH_CRC_DATA_WIDTH);

        // Unpack the control
        this.control = packer.unpack_field_int(rx_verification_pack::CONTROL_DATA_WIDTH);

        // Unpack the control crc
        this.control_crc = packer.unpack_field_int(rx_verification_pack::CONTROL_CRC_DATA_WIDTH);

        // Clear the payload before unpacking
        this.data = {};

        // Unpack data
        for (int i = 0; i < data_length; i++) begin
            this.data.push_back(packer.unpack_field_int($bits(byte)));
        end

        // Unpack the parity
        this.parity = packer.unpack_field_int(rx_verification_pack::PARITY_DATA_WIDTH);
    endfunction
endclass

`endif // __RX_ITEM
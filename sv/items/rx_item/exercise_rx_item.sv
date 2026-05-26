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
// Description: Simplified UVM sequence item for the basic exercise test.
//              No error injection, no half_packet — only clean packets with
//              length, control, data payload, and parity.
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
    rand bit  [rx_verification_pack::LENGTH_DATA_WIDTH      - 1 : 0]    length      = '{default : 0}; // Randomized stimulus field
    bit       [rx_verification_pack::LENGTH_CRC_DATA_WIDTH  - 1 : 0]    length_crc  = '{default : 0}; 
    rand bit  [rx_verification_pack::CONTROL_DATA_WIDTH     - 1 : 0]    control     = '{default : 0}; // Randomized stimulus field
    bit       [rx_verification_pack::CONTROL_CRC_DATA_WIDTH - 1 : 0]    control_crc = '{default : 0}; 
    rand byte                                                           data [$]    = {};             // Randomized stimulus field
    rand bit  [rx_verification_pack::PARITY_DATA_WIDTH      - 1 : 0]    parity      = '{default : 0}; // Randomized stimulus field

    /*-------------------------------------------------------------------------------
    -- UVM Macros.
    -------------------------------------------------------------------------------*/
    `uvm_object_utils_begin(rx_item)
        `uvm_field_sarray_int (length,      UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (length_crc,  UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (control,     UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (control_crc, UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_queue_int  (data,        UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (parity,      UVM_DEFAULT | UVM_NOPACK)
    `uvm_object_utils_end 

    /*------------------------------------------------------------------------------
    -- Parameters.
    ------------------------------------------------------------------------------*/
    rx_generation_parameters parameters;

    /*-------------------------------------------------------------------------------
    -- Constructor
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_item");
        super.new(name);
    endfunction

    /*-------------------------------------
    -- CRC Calculation Functions
    -------------------------------------*/

    /*-------------------------------------------------------------------------------
    -- Calculate CRC16 Generic
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
    -------------------------------------------------------------------------------*/
    function logic [15:0] calculate_crc16_len(input logic [15:0] data);
        return calculate_crc16_generic(data, rx_verification_pack::CRC_LEN_POLY, rx_verification_pack::CRC_LEN_INIT);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Calculate CRC16 Ctrl
    -------------------------------------------------------------------------------*/
    function logic [15:0] calculate_crc16_ctrl(input logic [15:0] data);
        return calculate_crc16_generic(data, rx_verification_pack::CRC_CTRL_POLY, rx_verification_pack::CRC_CTRL_INIT);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Post Randomize
    -- Calculates CRCs, data payload, and parity. No error injection.
    -------------------------------------------------------------------------------*/
    function void post_randomize();
        int unsigned p_width = rx_verification_pack::PARITY_DATA_WIDTH;
        int unsigned data_size;

        // Calculate CRC for length
        this.length_crc = calculate_crc16_len(this.length);

        // Calculate CRC for control
        this.control_crc = calculate_crc16_ctrl(this.control);

        // Calculate Data payload size (total length minus control+crc bytes)
        data_size = this.length - ((rx_verification_pack::CONTROL_DATA_WIDTH + rx_verification_pack::CONTROL_CRC_DATA_WIDTH) / 8);
        this.data.delete();

        // Generate random data bytes
        for (int i = 0; i < data_size; i++) begin
            this.data.push_back($urandom);
        end
        
        // Calculate Parity (XOR over 32-bit chunks, MSB-first byte ordering)
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
    endfunction

    /*-------------------------------------------------------------------------------
    -- Do Pack
    -- Serializes: length+CRC, control+CRC, data, parity. No errors injected.
    -------------------------------------------------------------------------------*/
    virtual function void do_pack(uvm_packer packer);
        // Pack Length + Length CRC
        packer.pack_field_int({this.length, this.length_crc}, $bits(this.length) + $bits(this.length_crc));
        // Pack Control + Control CRC
        packer.pack_field_int({this.control, this.control_crc}, $bits(this.control) + $bits(this.control_crc));
        // Pack Data
        foreach(this.data[i]) begin
            packer.pack_field_int(this.data[i], $bits(this.data[i]));
        end
        // Pack Parity
        packer.pack_field_int(this.parity, $bits(this.parity));
    endfunction

    /*-------------------------------------------------------------------------------
    -- Do Unpack
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

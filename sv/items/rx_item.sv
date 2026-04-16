////////////////////////////////////////////////////////////////////////////////
//
// File name    : rx_item.sv
// Project name : 
// Author       : 
// Date Created : 25/12
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Item to send to the module rx.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __RX_ITEM
`define __RX_ITEM

import uvm_pkg::*;
`include "uvm_macros.svh"

class rx_item extends uvm_object;

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/

    rand bit [rx_verification_pack::LENGTH_DATA_WIDTH      - 1 : 0] length = '{default : 0};
    bit [rx_verification_pack::LENGTH_CRC_DATA_WIDTH  - 1 : 0] length_crc = '{default : 0}; 
    rand bit [rx_verification_pack::CONTROL_DATA_WIDTH     - 1 : 0] control = '{default : 0}; 
    bit [rx_verification_pack::CONTROL_CRC_DATA_WIDTH - 1 : 0] control_crc = '{default : 0}; 
    rand byte data [$] = {}; 
    rand bit [rx_verification_pack::PARITY_DATA_WIDTH      - 1 : 0] parity = '{default : 0}; 
    rand bit length_error;
    rand bit wrong_length;
    rand bit control_error;
    rand bit parity_error;
    bit [rx_verification_pack::LENGTH_DATA_WIDTH   + rx_verification_pack::LENGTH_CRC_DATA_WIDTH   - 1 : 0] new_length_with_crc;
    bit [rx_verification_pack::CONTROL_DATA_WIDTH  + rx_verification_pack::CONTROL_CRC_DATA_WIDTH  - 1 : 0] new_control_with_crc;
    bit [rx_verification_pack::PARITY_DATA_WIDTH     - 1 : 0] new_parity;
    rand bit half_packet;
    /*-------------------------------------------------------------------------------
    -- UVM Macros.
    -------------------------------------------------------------------------------*/
    `uvm_object_utils_begin(rx_item)

        `uvm_field_sarray_int (length,        UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (length_crc,    UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (control,       UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (control_crc,   UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_queue_int  (data,          UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (parity,        UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_int        (length_error,  UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_int        (wrong_length,  UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_int        (control_error, UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_int        (parity_error,  UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (new_length_with_crc, UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (new_control_with_crc, UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_sarray_int (new_parity, UVM_DEFAULT | UVM_NOPACK)
        `uvm_field_int        (half_packet, UVM_DEFAULT | UVM_NOPACK)
    `uvm_object_utils_end 

    /*------------------------------------------------------------------------------
    -- Parameters.
    ------------------------------------------------------------------------------*/
    rx_generation_parameters parameters;
    // CRC polynomial and initialization parameters
    localparam bit [15:0] CRC_LEN_POLY = 16'h1021;
    localparam bit [15:0] CRC_LEN_INIT = 16'hFFFF;
    
    localparam bit [15:0] CRC_CTRL_POLY = 16'h8005;
    localparam bit [15:0] CRC_CTRL_INIT = 16'h0000;



    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new (string name = "rx_item");
        super.new(name);
    endfunction

    /*-------------------------------------
    -- CRC Calculation Functions
    -------------------------------------*/

    // Generic CRC16 calculation function
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

    // CRC16 calculation function for length field
    function logic [15:0] calculate_crc16_len(input logic [15:0] data);
        return calculate_crc16_generic(data, CRC_LEN_POLY, CRC_LEN_INIT);
    endfunction

    // CRC16 calculation function for control field
    function logic [15:0] calculate_crc16_ctrl(input logic [15:0] data);
        return calculate_crc16_generic(data, CRC_CTRL_POLY, CRC_CTRL_INIT);
    endfunction

    /*-------------------------------------
    -- Post Randomize
    -------------------------------------*/
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
        data_size = this.length - ((rx_verification_pack::CONTROL_DATA_WIDTH + rx_verification_pack::CONTROL_CRC_DATA_WIDTH) / 8);
        this.data.delete();
        $display("data_size: %d", data_size);
        for (int i=0; i < data_size; i++) begin
            this.data.push_back($urandom);
            // this.data.push_back(8'hFD);
            // if (i%4 == 0) this.data.push_back(8'hFD);
            // else this.data.push_back(8'hFE);
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
            $display("parity_error = %b, at %t", this.parity_error, $time);
            num_flips = $urandom_range(1, $bits(temp_parity)); 
            if (num_flips % 2 == 0) num_flips++; // Ensure odd number of flips
            for (int i = 0; i < num_flips; i++) begin
                bit_index = $urandom_range(0, $bits(temp_parity) - 1);
                temp_parity[bit_index] = ~temp_parity[bit_index];
            end
        end
        this.new_parity = temp_parity;
    endfunction

    /*-------------------------------------
    -- Do pack
    -------------------------------------*/
    virtual function void do_pack(uvm_packer packer);
        // 1. Construct stream of current item fields
        // Normal: Pack Length, Control, Data, Parity.
        packer.pack_field_int(this.new_length_with_crc, $bits(this.new_length_with_crc));
        // $display("length: %h, length_with_crc: %h", this.length, this.new_length_with_crc);
        packer.pack_field_int(this.new_control_with_crc, $bits(this.new_control_with_crc));
        // $display("control: %h, control_with_crc: %h", this.control, this.new_control_with_crc);
        // Pack Data
        foreach(this.data[i]) begin
            packer.pack_field_int(this.data[i], $bits(this.data[i]));
        end
        // Pack Parity
        packer.pack_field_int(this.new_parity, $bits(this.new_parity));
        // $display("length_with_crc: %h", this.new_length_with_crc);
        // $display("control_with_crc: %h", this.new_control_with_crc);
        // $display("data: %h", this.data);
        // $display("parity: %h", this.new_parity);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Do unpack
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
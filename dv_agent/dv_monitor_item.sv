////////////////////////////////////////////////////////////////////////////////
//
// File name    : dv_monitor_item.sv
// Project name : 
// Author       :
// Date Created : 12/2025
// Company      : IDF - Masad - Mador 34
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: A monitor item object for the dv interface.
//
////////////////////////////////////////////////////////////////////////////////
//
// Comments:
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __DV_MONITOR_ITEM
`define __DV_MONITOR_ITEM

import uvm_pkg::*;
`include "uvm_macros.svh"

class dv_monitor_item #(parameter int SEQUENCE_ITEM_WIDTH = 8) extends uvm_object;

    /*-------------------------------------------------------------------------------
    -- Members.
    -------------------------------------------------------------------------------*/
    bit[SEQUENCE_ITEM_WIDTH-1:0] data;

    /*-------------------------------------------------------------------------------
    -- UVM Macros.
    -------------------------------------------------------------------------------*/
    `uvm_object_param_utils_begin(dv_monitor_item #(SEQUENCE_ITEM_WIDTH))
        `uvm_field_sarray_int(data, UVM_DEFAULT | UVM_NOPACK) 
    `uvm_object_utils_end

    /*-------------------------------------------------------------------------------
    -- Constructor.
    -------------------------------------------------------------------------------*/
    function new(string name = "dv_monitor_item");
        super.new(name);
    endfunction

    /*-------------------------------------------------------------------------------
    -- Do pack.
    -------------------------------------------------------------------------------*/
    virtual function void do_pack(uvm_packer packer);

        // Pack the data
        packer.pack_field_int(this.data, $bits(this.data));
    endfunction

    /*-------------------------------------------------------------------------------
    -- Do unpack.
    -------------------------------------------------------------------------------*/
    virtual function void do_unpack(uvm_packer packer);

        // Unpack data
        this.data = packer.unpack_field_int($bits(this.data));
    endfunction
endclass

`endif // __DV_MONITOR_ITEM
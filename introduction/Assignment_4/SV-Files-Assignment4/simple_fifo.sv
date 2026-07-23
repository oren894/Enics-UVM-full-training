////////////////////////////////////////////////////////////////////////////////
//
// File name    :   simple_fifo.sv
// Project name :   SV_fifo_build
// Author       :   Oren Ruthstein
// Date Created :   07/2026
// Company      :   ENICS
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: A synchronous, single-clock FIFO. Build it from scratch.
// See ../README.md for the full spec and background reading.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __SIMPLE_FIFO
`define __SIMPLE_FIFO

module simple_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4     // must be a power of 2 for this exercise
) (
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,

    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty
);

    localparam int PTR_WIDTH   = $clog2(DEPTH);
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);

    logic [DATA_WIDTH-1:0]  mem [DEPTH];
    logic [PTR_WIDTH-1:0]   wr_ptr, rd_ptr;
    logic [COUNT_WIDTH-1:0] count;

    /*------------------------------------------------------------------------------
    --  EXERCISE - Build a synchronous FIFO:
    --
    --   - full  = (count == DEPTH), empty = (count == 0)          [combinational]
    --   - rd_data always shows mem[rd_ptr] - "fall-through" style: the head of
    --     the queue is visible on rd_data whenever the FIFO isn't empty, whether
    --     or not rd_en is asserted this cycle.                    [combinational]
    --   - on a write (wr_en && !full): mem[wr_ptr] <= wr_data, and wr_ptr moves
    --     to the next slot                                        [sequential]
    --   - on a read (rd_en && !empty): rd_ptr moves to the next slot
    --                                                              [sequential]
    --   - count tracks the net change each cycle: +1 on write-only, -1 on
    --     read-only, unchanged on simultaneous read+write or on neither
    --                                                              [sequential]
    --   - everything resets cleanly on !rst_n
    --
    --  DEPTH is a power of 2 on purpose - think about what that lets you do with
    --  plain binary addition on a PTR_WIDTH-bit pointer when it comes to wrapping
    --  back to 0 after the last slot.
    ------------------------------------------------------------------------------*/

    // INSERT YOUR CODE HERE!

endmodule

`endif // __SIMPLE_FIFO

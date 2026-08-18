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
// Description: A synchronous, single-clock FIFO.
//
// SOLUTION FILE - local answer key, not for students.
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

    // Combinational: always reflect current state, no cycle of delay.
    assign full    = (count == DEPTH);
    assign empty   = (count == 0);
    assign rd_data = mem[rd_ptr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            // Write side: only legal when not full.
            if (wr_en && !full) begin
                mem[wr_ptr] <= wr_data;
                // DEPTH is a power of 2, so a PTR_WIDTH-bit pointer wraps
                // back to 0 on its own via ordinary binary overflow - no
                // explicit "if at last slot, reset to 0" needed.
                wr_ptr      <= wr_ptr + 1'b1;
            end

            // Read side: only legal when not empty.
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            // count tracks the NET change this cycle: +1 write-only,
            // -1 read-only, unchanged on simultaneous read+write or idle.
            case ({wr_en && !full, rd_en && !empty})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule

`endif // __SIMPLE_FIFO

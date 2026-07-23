////////////////////////////////////////////////////////////////////////////////
//
// File name    :   01_decode_the_signal.sv
// Project name :   SV_basics
// Author       :
// Date Created :
// Company      :   Team Training
//
////////////////////////////////////////////////////////////////////////////////
//
// Topics: Data Structures, Loops, Streaming Operations.
// See ../MATERIAL.md for the full task write-up and background reading.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __DECODE_THE_SIGNAL
`define __DECODE_THE_SIGNAL

module decode_the_signal;

    // "Raw telemetry" - 8 noisy bytes off a sensor bus. Only indices 1, 3 and 5
    // carry real payload; the rest is noise.
    byte raw_telemetry[8] = '{8'h00, 8'hAA, 8'h11, 8'h5B, 8'h22, 8'h5D, 8'h33, 8'h44};

    byte       payload[3];
    bit [23:0] decoded_code;
    string     decoded_hex;

    initial begin

        /*--------------------------------------------------------------------------
        --  Part A - Data Structures + Loops
        --  Collect raw_telemetry[1], raw_telemetry[3] and raw_telemetry[5] - IN
        --  THAT ORDER - into payload[0], payload[1], payload[2]. Use a loop.
        --------------------------------------------------------------------------*/

        // INSERT YOUR CODE HERE!

        $display("Part A - payload = %p", payload);

        /*--------------------------------------------------------------------------
        --  Part B - Streaming Operations (the hard part!)
        --  payload is scrambled twice over, not once:
        --   1. The three bytes are in reversed order (payload[0] is really the
        --      LEAST significant byte of the real code, not the most significant).
        --   2. On top of that, the bits INSIDE each byte are also reversed
        --      (bit 7 and bit 0 swapped, bit 6 and bit 1 swapped, and so on).
        --
        --  A streaming operator can undo both scrambles in a single expression
        --  if you pick the right slice size - re-read the Streaming Operations
        --  section in MATERIAL.md and think about what "no slice size given"
        --  actually means before reaching for byte-level streaming.
        --------------------------------------------------------------------------*/

        // INSERT YOUR CODE HERE!

        decoded_hex = $sformatf("%h", decoded_code);
        decoded_hex = decoded_hex.toupper();

        if (decoded_code == 24'hBADA55)
            $display("S U C C E S S - decoded_code = 0x%0s. That's a %0s decode.", decoded_hex, decoded_hex);
        else
            $display("Not there yet - decoded_code = 0x%0s, expected 0xBADA55.", decoded_hex);

        $finish;
    end

endmodule

`endif // __DECODE_THE_SIGNAL

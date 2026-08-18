////////////////////////////////////////////////////////////////////////////////
//
// File name    :   01_decode_the_signal.sv
// Project name :   SV_basics
// Author       :   Oren Ruthstein
// Date Created :   07/2026
// Company      :   ENICS
//
////////////////////////////////////////////////////////////////////////////////
//
// Topics: Data Structures, Loops, Streaming Operations.
// See ../MATERIAL.md for the full task write-up and background reading.
//
// SOLUTION FILE - local answer key, not for students.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __DECODE_THE_SIGNAL
`define __DECODE_THE_SIGNAL

module decode_the_signal;

    // "Raw telemetry" - 8 bytes off a sensor bus. Only indices 1, 3 and 5
    // carry real payload; the rest is noise.
    byte raw_telemetry[8] = '{8'h00, 8'hBA, 8'h11, 8'hA5, 8'h22, 8'hD5, 8'h33, 8'h44};

    byte       payload[3];
    bit [23:0] decoded_code;
    bit [23:0] halves_swapped;   // intermediate result after step 1 of Part B
    string     decoded_hex;

    initial begin

        /*--------------------------------------------------------------------------
        --  Part A - Data Structures + Loops
        --  Collect raw_telemetry[1], raw_telemetry[3] and raw_telemetry[5] - IN
        --  THAT ORDER - into payload[0], payload[1], payload[2]. Use a loop.
        --------------------------------------------------------------------------*/

        // Indices 1, 3, 5 are exactly "2*i + 1" for i = 0, 1, 2.
        for (int i = 0; i < 3; i++) begin
            payload[i] = raw_telemetry[2*i + 1];
        end

        $display("Part A - payload = %p", payload);

        /*--------------------------------------------------------------------------
        --  Part B - Streaming Operations (the hard part!)
        --  Recover decoded_code from payload:
        --   1. Swap the first half of payload (the MSB half) with the last half
        --      (the LSB half).
        --   2. Within EACH byte, at its position after step 1, reverse the
        --      order of its bits (bit 7 <-> bit 0, bit 6 <-> bit 1, and so on).
        --
        --  Both steps are streaming operators - see MATERIAL.md for the two
        --  idioms you need and how they combine.
        --------------------------------------------------------------------------*/

        // Step 1: payload is 24 bits total, so "half" = 12 bits. {<<12{...}}
        // slices the 24-bit stream into two 12-bit chunks and swaps them -
        // this is a BIT-level swap, not a byte-level one, so it does not
        // land on byte boundaries.
        halves_swapped = {<<12{payload}};

        // Step 2: reverse every bit in the whole value (inner {<<{...}}),
        // then reverse the byte order back (outer {<<byte{...}}). Net
        // effect: only the bits inside each byte get reversed, byte order
        // is left exactly as step 1 produced it.
        decoded_code = {<<byte{ {<<{halves_swapped}} }};

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

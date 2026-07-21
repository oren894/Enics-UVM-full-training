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
    byte raw_telemetry[8] = '{8'h00, 8'hEE, 8'h11, 8'hFF, 8'h22, 8'hC0, 8'h33, 8'h44};

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
        --  payload holds the right bytes, but in reversed (network) byte order:
        --  payload[0] is really the LEAST significant byte of the real 24-bit
        --  code, not the most significant one. Use a streaming operator to
        --  reverse the byte order of payload into decoded_code below.
        --------------------------------------------------------------------------*/

        // INSERT YOUR CODE HERE!

        decoded_hex = $sformatf("%h", decoded_code);
        decoded_hex = decoded_hex.toupper();

        if (decoded_code == 24'hC0FFEE)
            $display("S U C C E S S - decoded_code = 0x%0s. Enjoy your %0s!", decoded_hex, decoded_hex);
        else
            $display("Not there yet - decoded_code = 0x%0s, expected 0xC0FFEE.", decoded_hex);

        $finish;
    end

endmodule

`endif // __DECODE_THE_SIGNAL

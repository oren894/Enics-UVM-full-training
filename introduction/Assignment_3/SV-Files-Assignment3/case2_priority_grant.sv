////////////////////////////////////////////////////////////////////////////////
//
// File name    :   case2_priority_grant.sv
// Project name :   SV_riddles
// Author       :   Oren Ruthstein
// Date Created :   07/2026
// Company      :   ENICS
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Case 2 - "The Phantom Latch"
//
// A 4-input priority grant block. It is NOT a blocking/non-blocking bug -
// every assignment in it uses "=" correctly. Something else is wrong.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __CASE2_PRIORITY_GRANT
`define __CASE2_PRIORITY_GRANT

`timescale 1ns/1ps

module case2_priority_grant (
    input  logic [3:0] req,
    output logic [3:0] grant
);

    /*------------------------------------------------------------------------------
    --  Exercise 2 - req[3] has the highest priority, req[0] the lowest. Exactly
    --  one grant bit should be set for the highest-priority active request, and
    --  grant should be 4'b0000 when req is all zero.
    --
    --  Run the testbench, sweep req over all 16 values (it does this for you),
    --  and watch grant on the waveform. Some values of req do not behave like a
    --  priority encoder at all - find out why, then fix it.
    ------------------------------------------------------------------------------*/
    always_comb begin
        if (req[3])
            grant = 4'b1000;
        else if (req[2])
            grant = 4'b0100;
        else if (req[1])
            grant = 4'b0010;
    end

endmodule

module case2_priority_grant_tb;

    logic [3:0] req;
    logic [3:0] grant;
    logic [3:0] expected_grant;
    int errors;

    case2_priority_grant dut (
        .req   (req),
        .grant (grant)
    );

    function automatic logic [3:0] priority_model(logic [3:0] r);
        if (r[3])      return 4'b1000;
        else if (r[2]) return 4'b0100;
        else if (r[1]) return 4'b0010;
        else if (r[0]) return 4'b0001;
        else           return 4'b0000;
    endfunction

    initial begin
        errors = 0;

        for (int i = 0; i < 16; i++) begin
            req = i[3:0];
            #10;
            expected_grant = priority_model(req);
            if (grant !== expected_grant) begin
                errors++;
                $display("[%0t] MISMATCH: req=%b  grant=%b  expected=%b", $time, req, grant, expected_grant);
            end else begin
                $display("[%0t] req=%b  grant=%b  OK", $time, req, grant);
            end
        end

        if (errors == 0)
            $display("S U C C E S S - grant matched the priority model for all 16 req combinations.");
        else
            $display("FOUND %0d MISMATCH(ES) - go look at the waveform around the failing req values.", errors);

        $finish;
    end

endmodule

`endif // __CASE2_PRIORITY_GRANT

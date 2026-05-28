////////////////////////////////////////////////////////////////////////////////
//
// File name    :   events.sv
// Project name :   SV_basics
// Author       :   
// Date Created :   
// Company      :   Team Training
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Part 6 
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __EVENTS 
`define __EVENTS

module events;

    /*------------------------------------------------------------------------------
    --  Exercise 1.
    ------------------------------------------------------------------------------*/
    initial begin 

        // You can edit this part, do not change the functions names. 
        fork
            randomize_votes(); 

            votes_timing(); 
        join 
    end
endmodule

`endif // __EVENTS
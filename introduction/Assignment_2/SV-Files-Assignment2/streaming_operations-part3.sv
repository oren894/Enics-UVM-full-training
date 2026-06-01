////////////////////////////////////////////////////////////////////////////////
//
// File name    :   streaming_operations.sv
// Project name :   SV_basics
// Author       :   
// Date Created :   
// Company      :   Sector Training
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Part 3 
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __STREAMING_OPERATIONS
`define __STREAMING_OPERATIONS

module streaming_operations;

    /*------------------------------------------------------------------------------
    --  Exercise 1.
    ------------------------------------------------------------------------------*/
    initial begin
        byte original_byte = 8'h3F;

        // INSERT YOUR CODE HERE!
    end

    /*------------------------------------------------------------------------------
    --  Exercise 2.
    ------------------------------------------------------------------------------*/
    initial begin
        string upper_str;

        // Given bit array.
        bit[23:0] arr = '{1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1 ,0 ,1 ,0, 1};

        // INSERT YOUR CODE HERE!

        // Display in upper case HEX form
        upper_str = $psprintf("%0h", arr);
        upper_str = upper_str.toupper();
        $display("%c[0;36m%0s%c[0m", 27, upper_str, 27);
    end
endmodule

`endif // __STREAMING_OPERATIONS
`ifndef __DV_IF
`define __DV_IF

interface dv_if #(parameter int unsigned DATA_WIDTH = 4) (input logic clk);
    wire [DATA_WIDTH-1:0] data;
    wire                  valid;

    // sequence sync_posedge;
    //     @(posedge clk) 1;
    // endsequence

    modport master (
        input clk,
        output data,
        output valid
    );
    modport slave (
        input clk,
        input data,
        input valid
    );
    modport monitor (
        input clk,
        input data,
        input valid
    );

    

    clocking slave_cb @(posedge clk);
    //    default input #1 output #1;
       input data;
       input valid;
    endclocking

    clocking master_cb @(posedge clk);
       default input #1;
       output data;
       output valid;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1 output #1;
        input data;
        input valid;
    endclocking

    task CLEAR_MASTER_CB();
        master_cb.valid <= 1'b0;
        master_cb.data  <= '0;
    endtask


endinterface

`endif // __DV_AGENT

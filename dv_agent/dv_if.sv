interface dv_if #(parameter int unsigned DATA_WIDTH = 4) (input clk);
    wire [DATA_WIDTH-1:0] data;
    wire                  valid;

    sequence sync_posedge;
        @(posedge clk) 1;
    endsequence

    clocking master_cb @(posedge clk);
        default input #1ps output #1ps;
        output data;
        output valid;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1ps;
        input data;
        input valid;
    endclocking

    modport master_mp (clocking master_cb);
    modport monitor_mp (clocking monitor_cb);

    task CLEAR_MASTER_CB();
        master_cb.valid <= 1'b0;
        master_cb.data  <= '0;
    endtask


endinterface
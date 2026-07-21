////////////////////////////////////////////////////////////////////////////////
//
// File name    :   02_the_rendezvous.sv
// Project name :   SV_basics
// Author       :
// Date Created :
// Company      :   Team Training
//
////////////////////////////////////////////////////////////////////////////////
//
// Topics: Tasks & Functions, Processes, Events.
// See ../MATERIAL.md for the full task write-up and background reading.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef __THE_RENDEZVOUS
`define __THE_RENDEZVOUS

module the_rendezvous;

    string racer_names[3] = '{"Alpha", "Bravo", "Charlie"};
    int    racer_times[3] = '{30, 55, 40};   // time units each racer needs to finish

    string finish_order[$];
    int    racers_done = 0;
    event  race_finished;

    /*------------------------------------------------------------------------------
    --  Part A - Tasks & Functions
    --  Write task run_racer(string name, int lap_time) that:
    --    1. waits `lap_time` time units (#lap_time)
    --    2. appends `name` to finish_order
    --    3. increments racers_done
    --    4. if racers_done == 3, triggers -> race_finished
    --
    --  It must stay declared "automatic": three racers are about to run this
    --  exact same task body at the same time - think about what would happen
    --  to `name` and `lap_time` if the task's own arguments were shared static
    --  storage instead of a fresh copy per call.
    ------------------------------------------------------------------------------*/
    task automatic run_racer(string name, int lap_time);
        // INSERT YOUR CODE HERE!
    endtask

    /*------------------------------------------------------------------------------
    --  Part B - Processes + Events (the hard part!)
    --  Launch all three racers to run AT THE SAME TIME (not one after another),
    --  then wait for the race_finished event before printing the result.
    ------------------------------------------------------------------------------*/
    initial begin

        // INSERT YOUR CODE HERE!

        if (finish_order.size() == 3)
            $display("S U C C E S S - finish order: %0s, %0s, %0s", finish_order[0], finish_order[1], finish_order[2]);
        else
            $display("Race never finished - only %0d racer(s) crossed the line. Did you launch all three in parallel and wait on the event?", finish_order.size());

        $finish;
    end

endmodule

`endif // __THE_RENDEZVOUS

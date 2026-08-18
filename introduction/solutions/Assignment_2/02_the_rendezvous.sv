////////////////////////////////////////////////////////////////////////////////
//
// File name    :   02_the_rendezvous.sv
// Project name :   SV_basics
// Author       :   Oren Ruthstein
// Date Created :   07/2026
// Company      :   ENICS
//
////////////////////////////////////////////////////////////////////////////////
//
// Topics: Tasks & Functions, Processes, Events.
// See ../MATERIAL.md for the full task write-up and background reading.
//
// SOLUTION FILE - local answer key, not for students.
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
        #lap_time;
        finish_order.push_back(name);
        racers_done++;
        if (racers_done == 3)
            -> race_finished;
    endtask

    /*------------------------------------------------------------------------------
    --  Part B - Processes + Events (the hard part!)
    --  Launch all three racers to run AT THE SAME TIME (not one after another),
    --  then wait for the race_finished event before printing the result.
    ------------------------------------------------------------------------------*/
    initial begin
        // join_none: kick all three off and keep going immediately - they run
        // concurrently. (Plain "join" would still be fine here since nothing
        // happens between the fork and the wait below, but join_none is the
        // idiom that generalizes to "launch and go do something else.")
        fork
            run_racer(racer_names[0], racer_times[0]);
            run_racer(racer_names[1], racer_times[1]);
            run_racer(racer_names[2], racer_times[2]);
        join_none

        @(race_finished);

        if (race_finished.triggered)
            $display("S U C C E S S - finish order: %0s, %0s, %0s", finish_order[0], finish_order[1], finish_order[2]);
        else
            $display("Race never finished. Did you launch all three in parallel and wait on the event?");

        $finish;
    end

endmodule

`endif // __THE_RENDEZVOUS

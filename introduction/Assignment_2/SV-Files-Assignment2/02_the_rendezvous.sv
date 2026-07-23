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
    --  then check whether race_finished has fired using its `.triggered`
    --  property instead of the edge-triggered @(race_finished) form.
    --
    --  A bare "if (race_finished.triggered)" checked once, right after the
    --  fork, will read false - the racers haven't had time to finish yet, and
    --  a one-shot if only looks at that single instant. Also don't try to
    --  catch it by polling .triggered on a fixed #delay loop - .triggered is
    --  only true during the exact time step the event fires, so a delay that
    --  doesn't happen to land on that exact moment will walk right past it.
    --  There's a statement built for exactly this: re-checking a condition
    --  and only proceeding once it's true, without you managing the polling
    --  yourself.
    ------------------------------------------------------------------------------*/
    initial begin
        // INSERT YOUR CODE HERE!

        if (finish_order.size() == 3)
            $display("S U C C E S S - finish order: %0s, %0s, %0s", finish_order[0], finish_order[1], finish_order[2]);
        else
            $display("Race never finished - only %0d racer(s) crossed the line. Did you launch all three in parallel and keep checking race_finished.triggered?", finish_order.size());

        $finish;
    end

endmodule

`endif // __THE_RENDEZVOUS

# Assignment 2 — Material & Tasks

This file replaces the old part-by-part PDF: for each of the three exercise files, it teaches just enough of each concept to recognize it and use it, then tells you exactly what to build. The examples below are deliberately **not** the exercises themselves — they're a different scenario using the same construct, so you still have to think about how to adapt the idea rather than copy it in. That's the point: you need to be able to look at each construct later and know what it's doing, not paste a snippet. Depth comes later, in Assignment 3 (Riddles) and the practical project.

Read [README.md](README.md) first for the run workflow (`tsmc65`, `list.f`, `runspace`, `xrun`). Each file below is self-contained — compile and run it on its own, e.g.:

```bash
xrun -gui -debug ../SV-Files-Assignment2/01_decode_the_signal.sv
```

---

## File 1 — `01_decode_the_signal.sv`

### Data Structures (quick reference)

SystemVerilog gives you several containers beyond plain fixed-size arrays:

| Type | Example | Notes |
|---|---|---|
| Fixed array | `byte arr[8];` | Size known at compile time. |
| Dynamic array | `int arr[];` then `arr = new[10];` | Size set at runtime. |
| Queue | `int q[$];` | Grows/shrinks; `push_back`, `push_front`, `pop_back`, `pop_front`, `.size()`. |
| Associative array | `int arr[string];` | Indexed by a key type instead of an integer. |
| Struct | `typedef struct {int a; bit b;} my_t;` | Groups fields together. |

You'll use a plain fixed array here — nothing fancy, just indexing, e.g. `raw_telemetry[4]`.

### Loops (quick reference)

```systemverilog
for (int i = 0; i < 8; i++) ...          // classic counting loop
foreach (raw_telemetry[i]) ...           // iterates every index of the array automatically
while (condition) ...                    // condition-driven loop
```

`foreach` is the one you'll reach for most often in verification code — it can't run off the end of the array by mistake. Note that `foreach` walks every index in order; if you only need *some* of the indices, you still need an `if` inside the loop (or a plain counting `for`) to pick them.

### Your Task — Part A

`raw_telemetry` is 8 bytes of noise with 3 real payload bytes hidden at indices 1, 3 and 5. Using any loop you like, copy `raw_telemetry[1]`, `raw_telemetry[3]`, `raw_telemetry[5]` — **in that order** — into `payload[0]`, `payload[1]`, `payload[2]`.

### Streaming Operations (quick reference)

The number after `<<` is the slice size the reordering operates on:

```systemverilog
byte four_bytes[4] = '{8'h11, 8'h22, 8'h33, 8'h44};

{four_bytes}                     // 32'h11223344 - plain concatenation, no reordering
{<<byte{four_bytes}}             // 32'h44332211 - byte order reversed, bits inside each byte untouched
{<<16{four_bytes}}               // 32'h33441122 - first half (16 bits) swapped with last half (16 bits)
{<<byte{ {<<{four_bytes}} }}     // 32'h8844CC22 - byte order UNCHANGED, bits inside each byte reversed
```

That last one is two streaming operators nested in a single expression: the inner one reverses every bit (which also flips byte order as a side effect), and the outer one swaps the byte order back - net effect, only the bits inside each byte end up reversed.

### Your Task — Part B (hardest part of this file)

Apply the "swap halves" idiom and the "reverse bits inside each byte, byte order unchanged" idiom above to `payload`, in that order, to get `decoded_code`.

---

## File 2 — `02_the_rendezvous.sv`

### Tasks & Functions (quick reference)

| | Function | Task |
|---|---|---|
| Can consume simulation time (`#`, `@`, `wait`) | No | Yes |
| Returns a value | Yes (or `void`) | No (only via `output`/`ref` args) |
| Typical use | Pure computation | Anything that waits on a clock, delay, or event |

```systemverilog
function bit is_prime(int n);
    if (n < 2) return 0;
    for (int d = 2; d < n; d++)
        if (n % d == 0) return 0;
    return 1;
endfunction

task automatic blink(string label, int period);
    repeat (3) begin
        #period;
        $display("%0s blink", label);
    end
endtask
```

**`automatic` matters.** By default, a task's local variables and *arguments* are static — shared across every call to that task, even concurrent ones. If two processes call the same non-automatic task at the same time (like `blink("A", 5)` and `blink("B", 7)` running in parallel), they'll stomp on each other's `label`/`period`. `automatic` gives each call its own private copy. Any task you plan to run from multiple parallel processes should be `automatic`.

### Your Task — Part A

Write `task automatic run_racer(string name, int lap_time)`. It should wait `lap_time` time units, append `name` to the `finish_order` queue, increment `racers_done`, and — once all three racers have finished — trigger the `race_finished` event.

### Processes (quick reference)

```systemverilog
fork
    do_a();
    do_b();
    do_c();
join       // waits for ALL three to finish
// join_any  waits for the FIRST one to finish, the rest keep running
// join_none returns immediately, all three keep running in the background
```

`fork` is what makes the three branches genuinely run *at the same time* — `join`, `join_any` and `join_none` only differ in whether/when the process that did the forking gets to continue. They don't change how the forked branches themselves run.

### Events (quick reference)

`fork...join` only synchronizes a parent with its own children. It's useless for coordinating two processes that have **no fork/join relationship to each other at all** — two independent `initial` blocks, for example. That's what events are for:

```systemverilog
event data_ready;
int   shared_value;

// producer process (some unrelated initial block):
shared_value = 42;
-> data_ready;                     // trigger it, AFTER the data is actually set

// consumer process (a completely different initial block):
@(data_ready);
$display("got %0d", shared_value); // guaranteed to see 42, not a stale value
```

There is no `join` that could connect these two processes — they aren't nested inside each other. The event is the only bridge between them. It has no value and no memory of its own, just a synchronization point: if it's triggered before anyone is waiting on it, that trigger is lost, so ordering matters — the producer sets `shared_value` *before* triggering, and the consumer only reads it *after* waiting, so it can never observe a half-updated value.

Every event also has a `.triggered` property, true if the event fired during the current time step — you'll see it used in the `.sv` file's final check, right after the wait, to confirm the trigger actually happened.

### Your Task — Part B (hardest part of this file)

Launch all three racers with `fork...join_none` so they run concurrently (not one after another), then `@(race_finished)` before printing the result.

Watch the finish order in the output — it reflects `racer_times`, not the order you wrote the `fork` statements in.

---

## File 3 — `03_generate_and_prove.sv`

### Randomization (quick reference)

```systemverilog
class dice_roll;
    rand bit [2:0] value;
    rand bit       is_bonus_round;

    constraint c_value { value inside {[1:6]}; }                    // range constraint
    constraint c_bonus { is_bonus_round dist {1 := 10, 0 := 90}; }  // weighted probability
endclass
```

`inside {[a:b]}` restricts a field to a range. `dist` gives you weighted probabilities instead of a uniform 50/50 — useful when you want something to happen "rarely" (like an error injection) instead of "half the time." This is exactly the mechanism the real project's `generation_parameters.sv` is built on.

To use a class like this, you still need the two ordinary steps you already know: construct an object (`new()`), then call `randomize()` on it as a plain statement. With constraints this simple, `randomize()` cannot fail, so there's no reason to guard it with `if (obj.randomize())` here — that pattern exists for when randomization genuinely *can* fail (conflicting constraints, `randomize()` called with extra `inline` constraints, etc.), which isn't the case in this exercise.

### Your Task — Part A

`stim_packet` (in the `.sv` file) has its `rand` fields declared but its constraints are empty — that part is yours to write, using `dice_roll` above as your syntax reference, not as something to copy field-for-field:
- `length` must always be inside the range 2 to 12 (inclusive)
- `urgent` should be 1 about 20% of the time, 0 the other 80%

Then create and randomize 5 `stim_packet` objects. For each one, `$display` it (length + urgent), then push its `length` field into the `lengths` queue — Part B's generator consumes this queue.

### Assertions (quick reference — the hardest topic in this training)

SystemVerilog Assertions (SVA) let you state a timing/behavioral rule and have the simulator check it automatically, every cycle, for the whole run:

```systemverilog
// "whenever read_valid is true, data_ack must become true within 2 to 8 cycles"
assert property (@(posedge clk) read_valid |-> ##[2:8] data_ack);

// "grant_a and grant_b must never both be true at once"
assert property (@(posedge clk) !(grant_a && grant_b));
```

- `|->` is implication: "if the left side matches, the right side must also match."
- `##[m:n]` is a bounded delay: "somewhere between m and n cycles later." (A plain `##k` means exactly `k` cycles later.)
- If an `assert property` ever fails, the simulator prints an assertion failure on its own — you don't have to check anything manually.

### Your Task — Part B (hardest part of this file — and of this whole assignment)

A generator (already written for you, in the `always_ff` block) drives `req`/`done` from the `lengths` queue. Read the timing description in the `.sv` file's comment block carefully — it tells you exactly how long `req` stays high and when `done` pulses. Write two assertions:

1. `p_mutex` — `req` and `done` must never both be high at the same cycle.
2. `p_eventual_done` — whenever `req` is high, `done` must go high within 1 to 20 cycles.

Use the `read_valid`/`data_ack` and `grant_a`/`grant_b` examples above as your template for the *shape* of each property — but you'll need different signal names and, for one of them, a different bound. If both properties hold for the entire run (no `ASSERTION FAILURE` printed), you've correctly specified — and proven — the timing contract of a block you never even had to look inside.

---

## When You're Done

All three files should run to `$finish` with no unexpected mismatches and no assertion failures. That's it for Assignment 2 — next up is Assignment 3 (Riddles), where you'll do the same kind of reasoning but by reading a waveform instead of trusting the console output.
